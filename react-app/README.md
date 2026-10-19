# Spring Café

A static, responsive café landing page built with the existing React 19, Vite 8, and Tailwind CSS 4 setup. All drink illustrations are local CSS; no external images, fonts, APIs, or backend are required.

## Run locally

```sh
npm install
npm run dev
```

## Production

```sh
npm run build
npm run preview
```

Deploy the generated `dist/` directory with your static web server. `npm run preview` is for checking the production build locally.

## Server badge

Change `SERVER_NAME` at the top of `src/App.jsx` from `WEB-01` to `WEB-02` for the second server, then rebuild. The badge appears in the green bar at the top of the page.

Menu content is in the `drinks` array in `src/App.jsx`. Opening hours, address, and contact details are sample content. Navigation links scroll to page sections; there is no ordering functionality.
