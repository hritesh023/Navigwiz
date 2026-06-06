import os
import io
import wave
import asyncio
import tempfile
import whisper


class AudioService:
    def __init__(self):
        self._whisper_model = None

    async def _get_whisper(self):
        if self._whisper_model is None:
            self._whisper_model = await asyncio.to_thread(whisper.load_model, "base")
        return self._whisper_model

    async def transcribe(self, audio_path: str) -> dict:
        model = await self._get_whisper()
        result = await asyncio.to_thread(model.transcribe, audio_path)
        return {
            "text": result["text"].strip(),
            "language": result.get("language", "en"),
            "segments": [
                {
                    "start": seg["start"],
                    "end": seg["end"],
                    "text": seg["text"].strip()
                }
                for seg in result.get("segments", [])
            ]
        }

    async def transcribe_bytes(self, audio_bytes: bytes) -> str:
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp.write(audio_bytes)
            tmp_path = tmp.name
        try:
            result = await self.transcribe(tmp_path)
            return result["text"]
        finally:
            os.unlink(tmp_path)

    async def text_to_speech(self, text: str, voice: str = "default") -> bytes:
        try:
            from TTS.api import TTS
            tts = await asyncio.to_thread(
                TTS, model_name="tts_models/en/ljspeech/tacotron2-DDC",
                progress_bar=False, gpu=False
            )
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
                await asyncio.to_thread(tts.tts_to_file, text=text, file_path=tmp.name)
                with open(tmp.name, "rb") as f:
                    audio_data = f.read()
                os.unlink(tmp.name)
                return audio_data
        except Exception as e:
            print(f"TTS failed, returning silence: {e}")
            with io.BytesIO() as wav_buffer:
                with wave.open(wav_buffer, "wb") as wav:
                    wav.setnchannels(1)
                    wav.setsampwidth(2)
                    wav.setframerate(24000)
                    wav.writeframes(b"\x00" * 24000)
                return wav_buffer.getvalue()


audio_service = AudioService()
