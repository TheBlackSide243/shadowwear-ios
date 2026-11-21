// The look chosen in Impostazioni → Aspetto, put on the page before it is drawn (this file is
// loaded first and is not a module, so the page never shows in the wrong colors).
(function () {
  var looks = { power: '#262642', ombra: '#0f0f11', bosco: '#12211c', oceano: '#0e2233', carta: '#f1f2f6' };
  var look = 'power';
  try { look = localStorage.getItem('sw-theme') || 'power'; } catch (e) { /* private window: the first look */ }
  if (!looks[look]) look = 'power';
  document.documentElement.dataset.theme = look;
  var meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.content = looks[look];
  var scheme = document.querySelector('meta[name="color-scheme"]');
  if (scheme) scheme.content = look === 'carta' ? 'light' : 'dark';
})();
