import crypto from "node:crypto";

export function pbkdf2Hash(secret) {
  const salt = crypto.randomBytes(16);
  const iterations = 150_000;
  const keylen = 32;
  const digest = "sha256";
  const hash = crypto.pbkdf2Sync(secret, salt, iterations, keylen, digest);
  return {
    algo: "pbkdf2",
    digest,
    iterations,
    salt: salt.toString("base64"),
    hash: hash.toString("base64"),
  };
}

export function pbkdf2Verify(secret, record) {
  if (!record || record.algo !== "pbkdf2") return false;
  const salt = Buffer.from(record.salt, "base64");
  const hash = Buffer.from(record.hash, "base64");
  const derived = crypto.pbkdf2Sync(secret, salt, record.iterations, hash.length, record.digest);
  return crypto.timingSafeEqual(hash, derived);
}

export function generateCode(len = 24) {
  // URL-safe, copy-paste friendly
  // e.g. 24 chars ~ 144 bits when using base64url-ish
  const bytes = crypto.randomBytes(Math.ceil((len * 6) / 8));
  return bytes
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "")
    .slice(0, len);
}

export function newSessionToken() {
  return crypto.randomBytes(24).toString("hex");
}
