// One delegated listener also handles forms replaced by Turbo.
document.addEventListener("change", (event) => {
  const input = event.target;
  if (input.id !== "micropost_image" || input.files.length === 0) return;
  if (input.files[0].size >= 5 * 1024 * 1024) {
    alert("Maximum file size is 5MB. Please choose a smaller file.");
    input.value = "";
  }
});
