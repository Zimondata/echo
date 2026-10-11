require "application_system_test_case"

class MobilePlannerDragScrollTest < ApplicationSystemTestCase
  setup do
    @previous_owner_id = ENV["ECHO_OWNER_TELEGRAM_ID"]
    @previous_local_bypass = ENV["ECHO_LOCAL_AUTH_BYPASS"]
    @previous_local_user_id = ENV["ECHO_LOCAL_USER_ID"]

    @user = User.create!(telegram_id: 998_877_661, first_name: "Mobile QA", timezone: "Europe/Madrid", language: "ru")
    ENV["ECHO_OWNER_TELEGRAM_ID"] = @user.telegram_id.to_s
    ENV["ECHO_LOCAL_AUTH_BYPASS"] = "1"
    ENV["ECHO_LOCAL_USER_ID"] = @user.id.to_s

    zone = Time.find_zone!(@user.timezone)
    @event = @user.calendar_events.create!(
      title: "Mobile drag scroll regression",
      start_time: zone.local(2026, 8, 8, 10),
      end_time: zone.local(2026, 8, 8, 11),
      event_type: "plan",
      priority: "medium"
    )
    (3..9).each do |day|
      next if day == 8

      @user.calendar_events.create!(
        title: "Week fixture #{day}",
        start_time: zone.local(2026, 8, day, 10),
        end_time: zone.local(2026, 8, day, 11),
        event_type: "plan",
        priority: "medium"
      )
    end
  end

  teardown do
    ENV["ECHO_OWNER_TELEGRAM_ID"] = @previous_owner_id
    ENV["ECHO_LOCAL_AUTH_BYPASS"] = @previous_local_bypass
    ENV["ECHO_LOCAL_USER_ID"] = @previous_local_user_id
  end

  test "pointer drop preserves the mobile planner scroll position" do
    page.driver.browser.manage.window.resize_to(430, 650)
    sign_in
    visit calendar_events_path(view: "week", date: "2026-08-08")

    source_selector = "[data-week-timeline-viewport] [data-week-layout-item='calendar-event'][data-planner-drag-event-id='#{@event.id}']"
    assert_selector source_selector
    source = find(source_selector)
    page.execute_script("document.documentElement.style.scrollBehavior = 'auto'; window.scrollTo(0, Math.max(180, arguments[0].getBoundingClientRect().top + window.scrollY - 260))", source)
    before = page.evaluate_script("window.scrollY")
    diagnostics = page.evaluate_script(<<~JS, source)
      (() => {
        const source = arguments[0]
        const ancestors = []
        for (let node = source.parentElement; node; node = node.parentElement) {
          const style = getComputedStyle(node)
          if (node.scrollHeight > node.clientHeight) ancestors.push({ tag: node.tagName, id: node.id, classes: node.className, overflowY: style.overflowY, top: node.scrollTop, height: node.clientHeight, scrollHeight: node.scrollHeight })
        }
        return { windowY: window.scrollY, innerHeight: window.innerHeight, rootHeight: document.scrollingElement.scrollHeight, sourceTop: source.getBoundingClientRect().top, ancestors }
      })()
    JS
    assert_operator before, :>=, 150, diagnostics.inspect

    page.execute_script(<<~JS, source)
      const source = arguments[0]
      const handle = source.querySelector("[data-planner-touch-handle]")
      const sourceDay = source.closest("[data-planner-drag-target='day']")
      const target = sourceDay.nextElementSibling || sourceDay.previousElementSibling
      handle.setPointerCapture = () => {}
      handle.releasePointerCapture = () => {}
      handle.hasPointerCapture = () => false
      const s = source.getBoundingClientRect()
      const t = target.getBoundingClientRect()
      const x = (t.left + t.right) / 2
      const y = Math.max(t.top + 30, Math.min(t.bottom - 30, s.top + 80))
      const fire = (type, clientX, clientY) => handle.dispatchEvent(new PointerEvent(type, {
        pointerId: 73, pointerType: "touch", button: 0, buttons: type === "pointerup" ? 0 : 1,
        clientX, clientY, bubbles: true, cancelable: true
      }))
      const originalElementFromPoint = document.elementFromPoint.bind(document)
      document.elementFromPoint = () => target
      fire("pointerdown", s.left + 12, s.top + 12)
      fire("pointermove", x, y)
      fire("pointerup", x, y)
      document.elementFromPoint = originalElementFromPoint
    JS

    assert_text "Событие перенесено"
    assert_selector source_selector
    restored_scroll = Selenium::WebDriver::Wait.new(timeout: 5).until do
      y = page.evaluate_script("window.scrollY")
      y if y >= 100
    end
    assert_operator restored_scroll, :>=, 100
  end

  test "a swipe starting on the card body remains scrolling intent" do
    page.driver.browser.manage.window.resize_to(430, 650)
    sign_in
    visit calendar_events_path(view: "week", date: "2026-08-08")

    source = find("[data-week-timeline-viewport] [data-week-layout-item='calendar-event'][data-planner-drag-event-id='#{@event.id}']")
    original_start = @event.reload.start_time
    result = page.evaluate_script(<<~JS, source)
      (() => {
        const source = arguments[0]
        const rect = source.getBoundingClientRect()
        const fire = (type, x, y) => source.dispatchEvent(new PointerEvent(type, {
          pointerId: 74, pointerType: "touch", button: 0, buttons: type === "pointerup" ? 0 : 1,
          clientX: x, clientY: y, bubbles: true, cancelable: true
        }))
        fire("pointerdown", rect.left + 8, rect.top + 8)
        fire("pointermove", rect.left + 8, rect.top + 60)
        fire("pointerup", rect.left + 8, rect.top + 60)
        return {
          touchAction: getComputedStyle(source).touchAction,
          dragging: source.classList.contains("is-pointer-dragging"),
          dropTargets: document.querySelectorAll(".is-planner-drop-target").length
        }
      })()
    JS

    assert_equal "auto", result.fetch("touchAction")
    assert_equal false, result.fetch("dragging")
    assert_equal 0, result.fetch("dropTargets")
    assert_equal original_start, @event.reload.start_time
  end

  test "does not restore a week offset after navigation to the day layout" do
    sign_in
    visit calendar_events_path(view: "week", date: "2026-08-08")
    page.execute_script(<<~JS)
      sessionStorage.setItem("echo:planner-drag-scroll", JSON.stringify({
        path: "/calendar_events", view: "week", x: 0, y: 300, savedAt: Date.now()
      }))
    JS

    visit calendar_events_path(view: "day", date: "2026-08-08")
    Selenium::WebDriver::Wait.new(timeout: 5).until do
      page.evaluate_script("sessionStorage.getItem('echo:planner-drag-scroll') === null")
    end

    assert_operator page.evaluate_script("window.scrollY"), :<, 20
  end

  private

  def sign_in
    auth_session = TelegramAuthSession.create!
    auth_session.confirm!(@user)
    visit root_path
    status = page.evaluate_async_script(<<~JS, auth_session.session_token)
      const token = arguments[0]
      const done = arguments[arguments.length - 1]
      fetch("/sessions/complete_telegram_auth", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ session_token: token })
      }).then(response => done(response.status)).catch(error => done(error.toString()))
    JS
    assert_equal 200, status
  end
end
