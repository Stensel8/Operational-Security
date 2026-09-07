import { test, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import App from './App';

test('renders the product app navbar', () => {
  render(<App />);
  const brand = screen.getByText(/product app/i);
  expect(brand).toBeInTheDocument();
});
