export function formatCurrency(value) {
  const amount = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(amount)) {
    return '';
  }
  return new Intl.NumberFormat('nl-NL', { style: 'currency', currency: 'EUR' }).format(amount);
}
