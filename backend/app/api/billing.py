"""Razorpay Standard Checkout for the Navigwiz backend.

Flow (the KEY_SECRET never leaves this server):
  1. POST /api/create-order  {amount (paise), currency?, receipt?, plan?}
     -> creates a Razorpay order, returns {order_id, amount, currency}.
  2. The client opens Razorpay Checkout (checkout.js on web, razorpay_flutter
     on mobile) with the returned order_id, then collects
     razorpay_payment_id + razorpay_signature.
  3. POST /api/verify-payment {razorpay_order_id, razorpay_payment_id,
     razorpay_signature} -> HMAC-SHA256(order|payment, KEY_SECRET) check.
     Match -> {ok: true}. Mismatch -> 400 and nothing is marked as paid.

Plan subscriptions for the apps are granted centrally (api.acronous.com);
these endpoints provide the framework-equivalent local checkout backend.
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


class CreateOrderRequest(BaseModel):
    amount: int = Field(..., description="Amount in paise (integer, >= 100)")
    currency: Optional[str] = Field(default=None, description="ISO currency, default INR")
    receipt: Optional[str] = Field(default=None, description="Merchant receipt id (<=40 chars)")
    plan: Optional[str] = Field(default=None, description="Optional plan label for order notes")


class CreateOrderResponse(BaseModel):
    order_id: str
    amount: int
    currency: str


class VerifyPaymentRequest(BaseModel):
    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str


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
    if body.amount is None or int(body.amount) < MIN_AMOUNT_PAISE:
        raise HTTPException(
            status_code=400,
            detail="Amount must be an integer >= 100 paise.",
        )
    amount = int(body.amount)
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
                "plan": (body.plan or "one_time")[:64],
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
    _ = user  # identity is required (401 otherwise); no ledger writes here.
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
    return {"ok": True}
