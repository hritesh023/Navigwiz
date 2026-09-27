"""Razorpay Standard Checkout for the Navigwiz backend.

Flow (the KEY_SECRET never leaves this server):
  1. POST /api/create-order  {plan}
      -> price is taken server-side from the central catalog
         (api.acronous.com/v1/billing/entitlements, mirrored below).
         Raw client-supplied amounts are rejected.
      -> creates a Razorpay order, returns {order_id, amount, currency}.
  2. The client opens Razorpay Checkout (checkout.js on web, razorpay_flutter
     on mobile) with the returned order_id, then collects
     razorpay_payment_id + razorpay_signature.
  3. POST /api/verify-payment {razorpay_order_id, razorpay_payment_id,
      razorpay_signature, plan} -> HMAC-SHA256(order|payment, KEY_SECRET)
      check + Razorpay order fetch binding (amount/plan/user must match).
      Match -> {ok: true}. Mismatch -> 400 and nothing is marked as paid.

Plan subscriptions for the apps are granted centrally (api.acronous.com);
these endpoints provide the framework-equivalent local checkout backend.
Clients should prefer the central worker; this backend never grants
entitlements itself.
"""

import hmac
import time
import uuid
from hashlib import sha256
from typing import Optional

import razorpay
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.config.settings import settings
from app.core.auth import verify_token

router = APIRouter(prefix="/api", tags=["billing"])

MIN_AMOUNT_PAISE = 100

# Central catalog mirror (prices in INR). Source of truth is
# Acronous-landing-page/billing/plans.json + entitlements.json.
# The backend NEVER trusts a client-supplied amount.
PLAN_PRICES_INR: dict = {
    "ai_starter_monthly": 149,
    "ai_plus_monthly": 449,
    "ai_pro_monthly": 999,
    "ai_ultra_monthly": 2499,
    "nav_ai_starter": 99,
    "nav_ai_plus": 299,
    "nav_ai_pro": 699,
    "nav_ai_ultra": 1499,
    "eq_plus": 49,
    "eq_premium": 149,
    "eq_creator": 399,
    "eq_creator_pro": 799,
    "acronous_one": 699,
    "api_pack_99": 99,
    "api_pack_499": 499,
    "api_pack_999": 999,
    "api_pack_2499": 2499,
}


class CreateOrderRequest(BaseModel):
    plan: str = Field(..., description="Catalog plan id (price taken server-side)")
    currency: Optional[str] = Field(default=None, description="ISO currency, default INR")
    receipt: Optional[str] = Field(default=None, description="Merchant receipt id (<=40 chars)")


class CreateOrderResponse(BaseModel):
    order_id: str
    amount: int
    currency: str


class VerifyPaymentRequest(BaseModel):
    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str
    plan: Optional[str] = Field(default=None, description="Catalog plan id being verified")


def _billing_client() -> razorpay.Client:
    key_id = (settings.razorpay_key_id or "").strip()
    key_secret = (settings.razorpay_key_secret or "").strip()
    if not key_id or not key_secret:
        raise HTTPException(
            status_code=503,
            detail="Billing is not configured yet. Please try again later.",
        )
    return razorpay.Client(auth=(key_id, key_secret))


@router.post("/create-order", response_model=CreateOrderResponse)
async def create_order(body: CreateOrderRequest, user: dict = Depends(verify_token)):
    plan = (body.plan or "").strip()[:64]
    if not plan or plan not in PLAN_PRICES_INR:
        raise HTTPException(status_code=400, detail="Unknown plan.")
    price_inr = PLAN_PRICES_INR[plan]
    if not price_inr or price_inr <= 0:
        raise HTTPException(
            status_code=400,
            detail="That plan is free or custom — no online payment needed.",
        )
    amount = int(round(price_inr * 100))
    if amount < MIN_AMOUNT_PAISE:
        raise HTTPException(
            status_code=400, detail="Amount must be an integer >= 100 paise."
        )
    currency = (body.currency or settings.razorpay_currency or "INR").upper()[:3] or "INR"
    receipt = (body.receipt or f"nav_{int(time.time())}_{uuid.uuid4().hex[:8]}")[:40]

    client = _billing_client()
    try:
        order = client.order.create({
            "amount": amount,
            "currency": currency,
            "receipt": receipt,
            "notes": {
                "user": str(user.get("email") or user.get("id") or ""),
                "plan": plan,
            },
        })
    except HTTPException:
        raise
    except Exception as e:
        status = getattr(e, "status_code", None) or getattr(e, "http_status", None)
        if status in (401, 403):
            raise HTTPException(status_code=401, detail="Billing authentication failed.")
        if status == 400:
            raise HTTPException(status_code=400, detail="Invalid order request.")
        raise HTTPException(
            status_code=500,
            detail="Could not create a payment order. Please try again.",
        )
    if not order or not order.get("id"):
        raise HTTPException(
            status_code=500,
            detail="Could not create a payment order. Please try again.",
        )
    return {
        "order_id": order["id"],
        "amount": int(order.get("amount", amount)),
        "currency": str(order.get("currency", currency)),
    }


@router.post("/verify-payment")
async def verify_payment(body: VerifyPaymentRequest, user: dict = Depends(verify_token)):
    key_id = (settings.razorpay_key_id or "").strip()
    key_secret = (settings.razorpay_key_secret or "").strip()
    if not key_secret:
        raise HTTPException(
            status_code=503,
            detail="Billing is not configured yet. Please try again later.",
        )
    order_id = (body.razorpay_order_id or "").strip()
    payment_id = (body.razorpay_payment_id or "").strip()
    signature = (body.razorpay_signature or "").strip()
    if not order_id or not payment_id or not signature:
        raise HTTPException(status_code=400, detail="Missing payment fields.")
    expected = hmac.new(
        key_secret.encode("utf-8"),
        f"{order_id}|{payment_id}".encode("utf-8"),
        sha256,
    ).hexdigest()
    if not hmac.compare_digest(expected, signature):
        # Signature mismatch: do NOT mark anything as paid.
        raise HTTPException(status_code=400, detail="Signature mismatch.")
    # Bind order -> amount/plan/user via Razorpay (stops replaying a small
    # payment as a bigger plan, or one user's payment as another's grant).
    claimed = (body.plan or "").strip()[:64] or None
    try:
        client = _billing_client()
        rz_order = client.order.fetch(order_id)
    except Exception:
        rz_order = None
    notes = (rz_order or {}).get("notes") or {}
    note_plan = notes.get("plan")
    plan = claimed or note_plan
    if not plan or plan not in PLAN_PRICES_INR:
        raise HTTPException(status_code=400, detail="Unknown plan for this order.")
    if claimed and note_plan and claimed != note_plan:
        raise HTTPException(status_code=400, detail="Plan does not match this order.")
    want = int(round(PLAN_PRICES_INR[plan] * 100))
    try:
        got = int((rz_order or {}).get("amount", want))
    except (TypeError, ValueError):
        got = want
    if rz_order is not None and got != want:
        raise HTTPException(status_code=400, detail="Amount does not match this plan.")
    note_user = notes.get("user")
    me = str(user.get("email") or user.get("id") or "")
    if note_user and me and note_user != me:
        raise HTTPException(status_code=403, detail="This order belongs to a different account.")
    _ = key_id  # key id is public per-order; kept for parity with central flow.
    return {"ok": True, "plan": plan}
