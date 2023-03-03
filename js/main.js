const LM = 'light-mode', DM = 'dark-mode';
const setTheme = (preference) => {
  let classList = document.body.classList;
  classList.remove(LM, DM);
  if (preference == LM) {
    classList.add(LM);
  } else if (preference == DM) {
    classList.add(DM);
  }
};

const newPreference = (oldpref) => {
  if (oldpref == DM) {
    return LM;
  } else if (oldpref == LM) {
    return DM;
  }
  let mm = window.matchMedia;
  return mm && mm('(prefers-color-scheme: dark)').matches ? LM : DM;
};

addEventListener('load', () => {
  const PT = 'theme-toggle';
  let toggle = document.getElementById(PT);
  let reset = document.getElementById('theme-reset');
  let preference = localStorage.getItem(PT);
  if (!preference) {
    reset.style.display = 'none';
  }
  toggle.onclick = () => {
    preference = newPreference(localStorage.getItem(PT));
    setTheme(preference);
    localStorage.setItem(PT, preference);
    reset.style.display = 'inline';
  };

  let canvas = document.createElement('canvas');
  let w = 48;
  canvas.width = w;
  canvas.height = w;
  Array.from(document.querySelectorAll('.blurhash')).forEach(img => {
    try {
      const ctx = canvas.getContext("2d");
      const imgdata = ctx.createImageData(w, w);
      imgdata.data.set(decode(img.dataset.hash, w, w));
      ctx.putImageData(imgdata, 0, 0);
      let data = canvas.toDataURL();
      img.src = data;
    } catch(err) { console.error(err); }
  });
});


fetch("/index.json").then(d => d.json()).then(d => console.log(d));
