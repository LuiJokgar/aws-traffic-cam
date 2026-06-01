const API_URL = 'https://i1ww8466t7.execute-api.us-east-1.amazonaws.com/prod/state';
const PLAYBACK_URL = 'https://11ea09e046fd.us-east-1.playback.live-video.net/api/video/v1/us-east-1.522868276800.channel.fG8PnizEHUGu.m3u8';

const player = IVSPlayer.create();
player.attachHTMLVideoElement(document.getElementById('player'));
player.addEventListener(IVSPlayer.PlayerState.READY, () => {
  player.setMuted(true);
  player.play();
});
player.load(PLAYBACK_URL);

function applyState(data) {
  const body = document.body;

  body.className = body.className
    .replace(/state-\S+/g, '')
    .replace(/weather-\S+/g, '')
    .replace(/time-\S+/g, '')
    .trim();

  body.classList.add(`state-${data.trafficLevel}`);
  body.classList.add(`weather-${data.weather}`);
  body.classList.add(`time-${data.timeOfDay}`);

  document.getElementById('traffic-badge').textContent = `Traffic: ${data.trafficLevel}`;
  document.getElementById('weather-badge').textContent = `Weather: ${data.weather}`;
  document.getElementById('time-badge').textContent = data.timeOfDay;
  document.getElementById('last-updated').textContent = `Last updated: ${new Date().toLocaleTimeString()}`;
}

async function fetchState() {
  try {
    const res = await fetch(API_URL);
    const data = await res.json();
    applyState(data);
  } catch (err) {
    console.error('Failed to fetch state:', err);
  }
}

fetchState();
setInterval(fetchState, 60000);