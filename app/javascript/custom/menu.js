// Add a click listener that toggles the given menu class.
function addToggleListener(selected_id, menu_id, toggle_class) {
  let selectedElement = document.querySelector(`#${selected_id}`);
  if (selectedElement) {
    selectedElement.addEventListener("click", function(event) {
      event.preventDefault();
      let menu = document.querySelector(`#${menu_id}`);
      menu.classList.toggle(toggle_class);
    });
  }
}

document.addEventListener("turbo:load", function() {
  addToggleListener("hamburger", "navbar-menu", "collapse");
  addToggleListener("account", "dropdown-menu", "active");
});
