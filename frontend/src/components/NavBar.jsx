import { NavLink } from "react-router-dom";

export default function NavBar() {
  return(
    <nav className="navbar navbar-expand-lg bg-body-tertiary">
      <div className="container-fluid">
        <NavLink className="navbar-brand" to="/">Product App</NavLink>

        <div className="collapse navbar-collapse" id="navbarSupportedContent">
          <ul className="navbar-nav me-auto mb-2 mb-lg-0">
            <li className="nav-item">
              <NavLink className={({ isActive }) => "nav-link" + (isActive ? " active" : "")} aria-current="page" to="/">List</NavLink>
            </li>
            <li className="nav-item">
              <NavLink className={({ isActive }) => "nav-link" + (isActive ? " active" : "")} to="/new">Add</NavLink>
            </li>
          </ul>
        </div>
      </div>
    </nav>
  );
}