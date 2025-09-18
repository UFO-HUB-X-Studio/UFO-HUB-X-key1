import express from "express";
import cors from "cors";
import morgan from "morgan";
import crypto from "crypto";

const app = express();
const PORT = process.env.PORT || 3000;
const SERVER_NAME = "UFO HUB X Key1 Server";

const SECRET = process.env.UFOX_SECRET || "dev-secret-key-1";       // ← ตั้งบน Render
const DEFAULT_TTL = Number(process.env.DEFAULT_TTL_SEC || 172800);  // 48h
const issued = new Map(); // key -> { uid, place, exp }

const okJson = (res, obj) => res.json({ ok: true, ...obj });
const badJson = (res, msg, code=400) => res.status(code).json({ ok:false, reason:msg });

const sig = (uid, place, exp) =>
  crypto.createHmac("sha256", SECRET).update(`${uid}:${place}:${exp}`).digest("hex").slice(0,24);

const keyOf = (uid, place, exp) => {
  const s = sig(uid, place, exp);
  const u = BigInt(Math.abs(Number(uid)||0)).toString(36).toUpperCase();
  const p = BigInt(Math.abs(Number(place)||0)).toString(36).toUpperCase();
  return `${u}-${p}-${s}`;
};

app.use(cors());
app.use(morgan("tiny"));

app.get("/", (_req, res) => res.type("text/plain").send(`${SERVER_NAME}: OK`));

app.get("/getkey", (req, res) => {
  const uid = String(req.query.uid||"");
  const place = String(req.query.place||"");
  if (!uid || !place) return badJson(res, "missing uid/place");

  const exp = Math.floor(Date.now()/1000) + DEFAULT_TTL;
  const key = keyOf(uid, place, exp);
  issued.set(key, { uid, place, exp });

  okJson(res, { key, expires_at: exp });
});

app.get("/verify", (req, res) => {
  const { key="", uid="", place="", format } = req.query;
  if (!key || !uid || !place) {
    return format==="json" ? badJson(res, "missing key/uid/place") : res.type("text/plain").send("INVALID");
  }

  const rec = issued.get(String(key).trim().toUpperCase());
  const now = Math.floor(Date.now()/1000);
  let valid = false, expOut = now + DEFAULT_TTL;

  if (rec && rec.uid===String(uid) && rec.place===String(place) && rec.exp > now) {
    valid = crypto.timingSafeEqual(
      Buffer.from(sig(uid, place, rec.exp)),
      Buffer.from(key.split("-")[2] || "")
    );
    if (valid) expOut = rec.exp;
  }

  if (format==="json") return okJson(res, { valid, expires_at: expOut });
  return res.type("text/plain").send(valid ? "VALID" : "INVALID");
});

app.listen(PORT, () => console.log(`[KEY1] ${SERVER_NAME} on ${PORT}`));
