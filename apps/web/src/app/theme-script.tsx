export function ThemeScript() {
  const script = `
    (function() {
      var pref = 'auto';
      try { pref = localStorage.getItem('simcast-theme') || 'auto'; } catch(e) {}
      var resolved = pref;
      if (pref === 'auto') {
        resolved = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
      }
      document.documentElement.dataset.theme = resolved;
    })();
  `;
  return <script dangerouslySetInnerHTML={{ __html: script }} />;
}
