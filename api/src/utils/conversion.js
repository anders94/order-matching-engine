/**
 * Convert asset amount (float) to base units (integer)
 * @param {number} amount - Amount in asset units (e.g., BTC, ETH)
 * @param {number} baseUnitScale - The base unit scale from the assets table
 * @returns {number} Amount in base units (e.g., satoshis, wei)
 */
function toBaseUnits(amount, baseUnitScale) {
  return Math.round(amount * parseFloat(baseUnitScale));
}

/**
 * Convert base units (integer) to asset amount (float)
 * @param {number} baseUnits - Amount in base units (e.g., satoshis, wei)
 * @param {number} baseUnitScale - The base unit scale from the assets table
 * @returns {number} Amount in asset units (e.g., BTC, ETH)
 */
function fromBaseUnits(baseUnits, baseUnitScale) {
  return baseUnits / parseFloat(baseUnitScale);
}

module.exports = {
  toBaseUnits,
  fromBaseUnits,
};
