import express from "express";
import cors from "cors";
import crypto from "crypto";
import dotenv from "dotenv";

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// ====== CONFIG ======
const SECRET = process.env.SECRET || "CHANGE_ME_SECRET"; // ต้องตั้งค่าให้เหมือนกันทุกเซิร์ฟเวอร์
const DEFAULT_TTL = Number(process.env.DEFAULT_TTL || 48 * 3600); // 48ชม.

// ====== HELPERS ======
const okJson  = (res, obj={}) => res.json({ ok:true, ...obj });
const badJson = (res, msg="error") => res.status(400).json({ ok:false, reason:msg });

const sig = (uid, place, exp) => {
  const h = crypto.createHmac("sha256", SECRET);
  h.update(String(uid) + ":" + String(place) + ":" + String(exp));
  return h.digest("hex").slice(0, 24).toUpperCase(); // ย่อให้อ่านง่าย
};

// สร้างคีย์: u36-p36-exp-sig
const makeKey = (uid, place, exp) => {
  const u = BigInt(Math.abs(Number(uid)||0)).toString(36).toUpperCase();
  const p = BigInt(Math.abs(Number(place)||0)).toString(36).toUpperCase();
  const s = sig(uid, place, exp);
  return `${u}-${p}-${exp}-${s}`;
};

// ตรวจคีย์
const verifyKey = (key, uid, place) => {
  const parts = String(key).trim().toUpperCase().split("-");
  if (parts.length !== 4) return { valid:false, exp:0 };

  const [u36, p36, expStr, sigPart] = parts;
  const exp = Number(expStr);
  if (!Number.isFinite(exp)) return { valid:false, exp:0 };

  const uCheck = BigInt(Math.abs(Number(uid)||0)).toString(36).toUpperCase();
  const pCheck = BigInt(Math.abs(Number(place)||0)).toString(36).toUpperCase();
  if (u36 !== uCheck || p36 !== pCheck) return { valid:false, exp };

  const want = sig(uid, place, exp);
  const okSig = Buffer.from(want).length === Buffer.from(sigPart).length &&
                crypto.timingSafeEqual(Buffer.from(want), Buffer.from(sigPart));
  const now = Math.floor(Date.now()/1000);
  return { valid: okSig && exp > now, exp };
};

// ====== MIDDLEWARE ======
app.use(cors());

// ====== ROUTES ======
app.get("/", (_req, res) => res.send("UFO HUB X Upstream: OK"));

app.get("/getkey", (req, res) => {
  const uid = String(req.query.uid||"");
  const place = String(req.query.place||"");
  if (!uid || !place) return badJson(res, "missing uid/place");
  const exp = Math.floor(Date.now()/1000) + DEFAULT_TTL;
  const key = makeKey(uid, place, exp);
  okJson(res, { key, expires_at: exp });
});

app.get("/verify", (req, res) => {
  const { key="", uid="", place="", format } = req.query;
  if (!key || !uid || !place) {
    return format==="json" ? badJson(res, "missing key/uid/place")
                           : res.type("text/plain").send("INVALID");
  }
  const { valid, exp } = verifyKey(key, uid, place);
  if (format==="json") return okJson(res, { valid, expires_at: exp });
  return res.type("text/plain").send(valid ? "VALID" : "INVALID");
});

// ====== START ======
app.listen(PORT, () => {
  console.log(`[UPSTREAM] listening on ${PORT}`);
});
