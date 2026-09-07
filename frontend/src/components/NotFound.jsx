import { NavLink } from "react-router-dom";

export default function NotFound() {
  return (
    <div className="d-flex flex-column align-items-center text-center py-5">
      <div className="display-1 fw-bold text-primary mb-3">404</div>
      <h1 className="h4 mb-3">Page not found</h1>
      <p className="text-body-secondary mb-4">This page doesn't exist. It may have been moved, or the link is wrong.</p>
      <NavLink to="/" className="btn btn-primary">Back to products</NavLink>
    </div>
  );
}
