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

const del = id => document.getElementById(id).remove();
let canvas = null;
const blurhash = img => {
  canvas = canvas || document.createElement('canvas');
  let w = 48;
  canvas.width = w;
  canvas.height = w;
  try {
    const ctx = canvas.getContext("2d");
    const imgdata = ctx.createImageData(w, w);
    imgdata.data.set(decode(img.dataset.hash, w, w));
    ctx.putImageData(imgdata, 0, 0);
    let data = canvas.toDataURL();
    img.src = data;
  } catch(err) { console.error(err); }
};

const p = d => d < 10 ? '0' + d : d;
const sa = (r, el, a, v) => r.querySelector(el).setAttribute(a, v);

let grid, templ;
const append_images = images => {
  images.forEach(f => {
    let node = templ.content.cloneNode(true);
    let date = new Date(f.d);
    sa(node, 'a', 'href', "/" + date.getFullYear() + "/" + p(date.getMonth() + 1) + '/' + p(date.getDate()) + '/post.html');
    sa(node, 'img', 'src', "/thumbnail/" + date.getFullYear() + "-" + p(date.getMonth() + 1) + '-' + p(date.getDate()) + '.jpeg');
    let bh = node.querySelector('img.blurhash');
    bh.dataset.hash = f.b;
    let img = node.querySelector('img.real');
    img.onload = bh.remove();
    blurhash(bh);
    node.querySelector('.date').innerText = date.toLocaleString('default', {year: 'numeric', day: 'numeric', month: 'long'});
    let l = node.querySelector('.location');
    if (f.l) {
      l.innerHTML = "&#x1F4CD; " + f.l;
    } else {
      l.remove();
    }
    grid.appendChild(node);
  });
  if (images.length == 0) {
    document.querySelector('.loading-indicator').innerText = "That's all."
  }
};
let images;
const scrolled = () => {
  let m = Math.min(window.innerWidth, 1200) / 3;
  if (window.innerHeight + window.pageYOffset + m >= document.body.offsetHeight) {
    if (!images) return;
    append_images(images.splice(0, 6));
  }
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

  window.addEventListener('scroll', scrolled);

  Array.from(document.querySelectorAll('.blurhash')).forEach(blurhash);
  templ = document.getElementById('post-template');
  grid = document.querySelector('.grid')
  if (grid && templ) {
    let year = new URLSearchParams(window.location.search).get('year');
    fetch("/api/posts.json")
      .catch(err => console.err(err))
      .then(d => d.json())
      .then(d => {
        let idx = 0;
        if (year) {
          for (let i in d) {
            if (new Date(d[i].d).getFullYear() <= year) {
              idx = i;
              break;
            }
          }
        }
        images = d.slice(idx);
        append_images(images.splice(0, 9));
        scrolled();
      });
  }
});
