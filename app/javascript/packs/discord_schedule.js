document.addEventListener("DOMContentLoaded", _ => {
  // Convert UTC timestamps to the browser's local time.
  document.querySelectorAll('span.datetime').forEach(e => {
    const date = new Date(e.innerText);
    e.innerText = date.toLocaleDateString('default', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: 'numeric',
      minute: '2-digit',
    });
  });
});
