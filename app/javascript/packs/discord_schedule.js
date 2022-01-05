document.addEventListener("DOMContentLoaded", _ => {
  const serverSelect = document.querySelector('select#server_id');
  serverSelect.onchange = e => {
    const serverID = e.target.value;
    const channelSelect = document.querySelector('select#channel_id');
    serverSelect.disabled = true;
    channelSelect.disabled = true;

    if (serverID === '') {
      // Remove all old channels from the dropdown.
      while (channelSelect.options.length > 0) {
        channelSelect.remove(0);
      }
      channelSelect.add(new Option('Choose a server first', ''));
      serverSelect.disabled = false;
    } else {
      fetch(`/discord_servers/${serverID}/channels.json`).then(response => {
        response.json().then(channels => {
          // Remove all old channels from the dropdown.
          while (channelSelect.options.length > 0) {
            channelSelect.remove(0);
          }
          // Add an empty option to the top and make the field required.
          channelSelect.add(new Option('', ''));
          channelSelect.required = true;
          // Add all this server's channels to the dropdown.
          channels.forEach(channel => {
            channelSelect.add(new Option(`#${channel.name}`, channel.id));
          });
          // Add a shortcut to send a message to all cohort channels.
          // The string 'cohort-' is referenced in Ruby as COHORT_CHANNEL_PREFIX / @all_cohort_key.
          channelSelect.add(new Option('All cohort channels', 'cohort-'));

          channelSelect.disabled = false;
          serverSelect.disabled = false;
        });
      });
    }
  };
});
