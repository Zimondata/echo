// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "channels"

const ECHO_THEMES = {
  "dark-violet": { scheme: "dark", paired: "light-violet", color: "#09090f" },
  "light-violet": { scheme: "light", paired: "dark-violet", color: "#f6f3fa" }
}

const normalizeEchoTheme = (theme) => ECHO_THEMES[theme] ? theme : null

const storedEchoTheme = () => {
  try {
    return normalizeEchoTheme(localStorage.getItem("echo-theme"))
  } catch (_) {
    return null
  }
}

const requestedEchoTheme = () => normalizeEchoTheme(new URL(window.location.href).searchParams.get("theme"))

const persistEchoTheme = (theme) => {
  try {
    localStorage.setItem("echo-theme", theme)
  } catch (_) {
    // Theme switching remains available when storage is blocked.
  }
}

const applyEchoTheme = (theme, { persist = true } = {}) => {
  const normalized = normalizeEchoTheme(theme) || "dark-violet"
  const config = ECHO_THEMES[normalized]

  document.documentElement.dataset.theme = normalized
  document.documentElement.dataset.colorScheme = config.scheme
  document.documentElement.style.colorScheme = config.scheme
  if (persist) persistEchoTheme(normalized)

  const meta = document.querySelector("#echo-theme-color")
  if (meta) meta.setAttribute("content", config.color)

  document.querySelectorAll("[data-theme-toggle]").forEach((button) => {
    const light = config.scheme === "light"
    button.setAttribute("aria-pressed", String(light))
    button.setAttribute("aria-label", light ? "Включить Violet" : "Включить Lavender")
    button.setAttribute("title", light ? "Переключить на Violet" : "Переключить на Lavender")
  })
}

const bindEchoTheme = () => {
  const requested = requestedEchoTheme()
  const current = normalizeEchoTheme(document.documentElement.dataset.theme)
  applyEchoTheme(requested || storedEchoTheme() || current || "dark-violet", { persist: Boolean(requested) })

  document.querySelectorAll("[data-theme-toggle]").forEach((button) => {
    if (button.dataset.themeBound === "true") return
    button.dataset.themeBound = "true"
    button.addEventListener("click", () => {
      const active = normalizeEchoTheme(document.documentElement.dataset.theme) || "dark-violet"
      applyEchoTheme(ECHO_THEMES[active].paired)
    })
  })
}

document.addEventListener("turbo:load", bindEchoTheme)
document.addEventListener("DOMContentLoaded", bindEchoTheme)
