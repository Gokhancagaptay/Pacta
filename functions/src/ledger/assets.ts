// İstemcideki karşılığı lib/core/money/asset.dart; ikisi de
// contracts/assets.json ile testlerde karşılaştırılır.

export interface AssetInfo {
  code: string;
  scale: number;
  symbol: string;
  label: string;
}

export const ASSETS: AssetInfo[] = [
  {code: "TRY", scale: 2, symbol: "₺", label: "Türk lirası"},
  {code: "USD", scale: 2, symbol: "$", label: "ABD doları"},
  {code: "EUR", scale: 2, symbol: "€", label: "Euro"},
  {code: "GAU", scale: 3, symbol: "gr", label: "Gram altın"},
  {code: "CEYREK", scale: 0, symbol: "çeyrek", label: "Çeyrek altın"},
];

export const ASSET_CODES = ["TRY", "USD", "EUR", "GAU", "CEYREK"] as const;

/** Tutar üst sınırı; JS'te toplamlar 2^53 altında kalır. */
export const MAX_MINOR = 10_000_000_000_000;

/**
 * Küçük birimdeki tutarı "1.234,50 ₺" biçiminde yazar.
 * @param {number} minor Küçük birim cinsinden tutar.
 * @param {string} code Birim kodu.
 * @return {string} Biçimli tutar.
 */
export function formatMinor(minor: number, code: string): string {
  const asset = ASSETS.find((a) => a.code === code);
  if (!asset) return `${minor} ${code}`;
  const unit = 10 ** asset.scale;
  const abs = Math.abs(minor);
  const whole = Math.floor(abs / unit)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  const fraction = (abs % unit).toString().padStart(asset.scale, "0");
  const number = asset.scale === 0 ? whole : `${whole},${fraction}`;
  return `${minor < 0 ? "−" : ""}${number} ${asset.symbol}`;
}
