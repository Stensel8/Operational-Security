const BLOCKED_KEYS = ['e', 'E', '+', '-'];

export function blockNonNumericKeys(event) {
  if (BLOCKED_KEYS.includes(event.key)) {
    event.preventDefault();
  }
}
