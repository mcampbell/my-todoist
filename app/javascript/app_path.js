// Prefix an app path with the mount point ("" at the root, "/todo" behind
// nginx). The layout renders it, so JS URLs follow wherever the app is served.
const scriptName = document.querySelector('meta[name="script-name"]')?.content || "";

export function appPath(path) {
  return scriptName + path;
}
