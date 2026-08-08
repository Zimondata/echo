require "application_system_test_case"

class MobileTaskStructureAndRhythmsTest < ApplicationSystemTestCase
  setup do
    @previous_owner_id = ENV["ECHO_OWNER_TELEGRAM_ID"]
    @previous_local_bypass = ENV["ECHO_LOCAL_AUTH_BYPASS"]
    @previous_local_user_id = ENV["ECHO_LOCAL_USER_ID"]

    @user = User.create!(telegram_id: 998_877_662, first_name: "Structure QA", timezone: "Europe/Madrid", language: "ru")
    ENV["ECHO_OWNER_TELEGRAM_ID"] = @user.telegram_id.to_s
    ENV["ECHO_LOCAL_AUTH_BYPASS"] = "1"
    ENV["ECHO_LOCAL_USER_ID"] = @user.id.to_s

    @project = @user.projects.create!(name: "Нейросамурай — контент и запуск")
    @someday = @user.tasks.create!(title: "Разобрать идею", status: "someday", project: @project)
    @someday.task_steps.create!(text: "Открыть заметку", position: 0)
    @unassigned = @user.tasks.create!(title: "Без дома", status: "someday")

    @rhythm = @user.rhythms.create!(
      name: "Тренировка",
      minimum_version: "Разминка",
      full_version: "Полная тренировка",
      position: 0
    )
    @rhythm.rhythm_checkins.create!(local_date: Date.new(2026, 8, 1), state: "full")
    @rhythm.rhythm_checkins.create!(local_date: Date.new(2026, 8, 2), state: "minimum")
    @rhythm.rhythm_checkins.create!(local_date: Date.new(2026, 8, 3), state: "skipped")
    @rhythm.rhythm_checkins.create!(
      local_date: Date.new(2026, 8, 4), state: "returned", previous_state: "skipped", returned_at: Time.current
    )
  end

  teardown do
    ENV["ECHO_OWNER_TELEGRAM_ID"] = @previous_owner_id
    ENV["ECHO_LOCAL_AUTH_BYPASS"] = @previous_local_bypass
    ENV["ECHO_LOCAL_USER_ID"] = @previous_local_user_id
  end

  test "mobile task capture details checklist and someday transition persist without page overflow" do
    mobile_sign_in
    visit tasks_path(status: "someday")

    assert_mobile_width_without_page_overflow
    assert_selector "[data-project-section='#{@project.id}'] [data-task-id='#{@someday.id}']"
    assert_selector "[data-project-section='none'] [data-task-id='#{@unassigned.id}']"
    page.execute_script("document.documentElement.style.scrollBehavior = 'auto'; arguments[0].scrollIntoView({ block: 'start' })", find("[data-project-section='#{@project.id}']"))
    save_qa_screenshot("tasks-someday-mobile.png")

    within "[data-task-id='#{@someday.id}']" do
      find("summary", text: "Детали").click
      fill_in "task[description]", with: "Проверенный контекст"
      click_button "Сохранить детали"
    end
    assert_text "Задача обновлена"
    assert_equal "Проверенный контекст", @someday.reload.description

    within "[data-task-id='#{@someday.id}']" do
      click_button "В следующие"
    end
    assert_text "Задача перенесена в следующие"
    assert_equal "next", @someday.reload.status

    visit tasks_path(status: "inbox")
    assert_selector "details[data-quick-capture-details]:not([open])"
    fill_in "Новая задача", with: "Схватить одной строкой"
    click_button "Добавить"
    assert_text "Задача добавлена"
    assert @user.tasks.exists?(title: "Схватить одной строкой", status: "inbox")
    assert_mobile_width_without_page_overflow
  end

  test "project rename stays usable at 390 pixels and persists" do
    mobile_sign_in
    visit projects_path

    assert_mobile_width_without_page_overflow
    project_row = find("[data-project-id='#{@project.id}']")
    page.execute_script("document.documentElement.style.scrollBehavior = 'auto'; arguments[0].scrollIntoView({ block: 'start' })", project_row)
    within project_row do
      find("summary", text: "Переименовать").click
      assert_selector "details[open]"
      field = find("input[name='project[name]']", visible: true)
      assert_equal "Новое название проекта", field["aria-label"]
      field.set("Echo переименован")
      click_button "Сохранить"
    end

    assert_text "Проект переименован"
    assert_equal "Echo переименован", @project.reload.name
    assert_mobile_width_without_page_overflow
    page.execute_script("document.documentElement.style.scrollBehavior = 'auto'; arguments[0].scrollIntoView({ block: 'start' })", find("[data-project-id='#{@project.id}']"))
    save_qa_screenshot("projects-rename-mobile.png")
  end

  test "mobile project workspace opens and keeps new work inside the project" do
    mobile_sign_in
    visit projects_path

    within "[data-project-id='#{@project.id}']" do
      click_link "Открыть"
    end

    assert_current_path project_path(@project)
    assert_mobile_width_without_page_overflow
    assert_selector "[data-project-status='someday'] [data-task-id='#{@someday.id}']"
    fill_in "Новая задача", with: "Собрать проектный план"
    click_button "Добавить"

    assert_text "Задача добавлена"
    created = @user.tasks.find_by!(title: "Собрать проектный план")
    assert_equal @project, created.project
    assert_current_path project_path(@project)
    assert_selector "[data-project-status='inbox'] [data-task-id='#{created.id}']"
    assert_mobile_width_without_page_overflow
    save_qa_screenshot("project-workspace-mobile.png")
  end

  test "mobile next workspace surfaces three compact priorities before the remaining queue" do
    tasks = [
      @user.tasks.create!(title: "Трафик · Telegram Ads", status: "next", project: @project, next_action: "Зафиксировать тестовый brief", due_on: Date.new(2026, 8, 10), estimate_minutes: 45),
      @user.tasks.create!(title: "Рост · Запустить SEO", status: "next", project: @project, next_action: "Собрать первый brief", due_on: Date.new(2026, 8, 11), estimate_minutes: 90),
      @user.tasks.create!(title: "Контент · YouTube про Hermes", status: "next", project: @project, next_action: "Утвердить hook", due_on: Date.new(2026, 8, 12), estimate_minutes: 45),
      @user.tasks.create!(title: "Продукт · Buddy", status: "next", project: @project, next_action: "Собрать кликабельный flow", due_on: Date.new(2026, 8, 13), estimate_minutes: 90)
    ]

    mobile_sign_in
    visit tasks_path(status: "next")

    assert_mobile_width_without_page_overflow
    assert_selector "[data-weekly-focus] [data-focus-task]", count: 3
    assert_selector "[data-task-list] [data-task-id='#{tasks.last.id}']", count: 1
    assert_selector "[data-workstream]", text: "Трафик"
    assert_no_selector "[data-weekly-focus] [data-focus-task='#{tasks.last.id}']"

    metrics = page.evaluate_script(<<~JS)
      [...document.querySelectorAll("[data-weekly-focus] [data-focus-task]")].map(row => ({
        height: row.getBoundingClientRect().height,
        actions: [...row.querySelectorAll(".echo-task-actions .echo-button")].map(button => button.getBoundingClientRect().height)
      }))
    JS
    assert metrics.all? { |metric| metric["height"] <= 260 }, metrics.inspect
    assert metrics.all? { |metric| metric["actions"].length <= 2 }, metrics.inspect
    assert metrics.flat_map { |metric| metric["actions"] }.all? { |height| height >= 44 }, metrics.inspect

    page.execute_script("document.documentElement.style.scrollBehavior = 'auto'; arguments[0].scrollIntoView({ block: 'start' })", find("[data-weekly-focus]"))
    save_qa_screenshot("tasks-next-focus-mobile.png")
  end

  test "day plan stays dense while exact timeline remains available on demand" do
    zone = Time.find_zone!(@user.timezone)
    day = Date.new(2026, 8, 9)
    9.times do |index|
      @user.tasks.create!(
        title: "Задача без времени #{index + 1}",
        status: "next",
        next_action: "Следующий конкретный шаг для задачи #{index + 1}",
        due_on: day
      )
    end
    [ [ 5, "Подъём" ], [ 7, "Море" ], [ 10, "Плавание" ], [ 19, "Семья" ] ].each do |hour, title|
      @user.calendar_events.create!(
        title: title,
        start_time: zone.local(2026, 8, 9, hour),
        end_time: zone.local(2026, 8, 9, hour + 1),
        event_type: "plan",
        priority: "medium"
      )
    end

    mobile_sign_in
    page.driver.browser.manage.window.resize_to(1280, 800)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: 1280,
      height: 800,
      deviceScaleFactor: 1,
      mobile: false
    )
    visit calendar_events_path(view: "day", date: day.iso8601)
    find(".task-lane-summary").click

    assert_selector "[data-task-card]", count: 9
    assert_selector ".calendar-day-checklist__item", count: 4
    assert_selector "details[data-day-timeline-disclosure]:not([open])"
    assert_no_selector ".calendar-day-timeline-shell", visible: true
    heights = page.evaluate_script("[...document.querySelectorAll('[data-task-card]')].map(card => card.getBoundingClientRect().height)")
    assert heights.all? { |height| height <= 72 }, heights.inspect
    save_qa_screenshot("calendar-day-dense-desktop.png")

    page.driver.browser.manage.window.resize_to(390, 844)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: 390,
      height: 844,
      deviceScaleFactor: 1,
      mobile: true
    )
    visit calendar_events_path(view: "day", date: day.iso8601)
    assert_mobile_width_without_page_overflow
    assert_selector "details[data-day-timeline-disclosure]:not([open])"
    find(".task-lane-summary").click
    mobile_task_controls = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".task-form .task-input, .task-form .task-submit")].map(control => ({
        width: control.getBoundingClientRect().width,
        height: control.getBoundingClientRect().height
      }))
    JS
    assert mobile_task_controls.all? { |control| control["width"] >= 44 && control["height"] >= 44 }, mobile_task_controls.inspect
    first("[data-task-card]").find("summary", text: "Запланировать").click
    mobile_scheduler_controls = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".task-card-scheduler[open] .task-schedule-form .task-input, .task-card-scheduler[open] .task-schedule-form .task-card-primary, .task-card-scheduler[open] .task-schedule-form .task-schedule-lock")].map(control => ({
        width: control.getBoundingClientRect().width,
        height: control.getBoundingClientRect().height
      }))
    JS
    assert mobile_scheduler_controls.all? { |control| control["width"] >= 44 && control["height"] >= 44 }, mobile_scheduler_controls.inspect
    find(".task-lane-summary").click
    mobile_controls = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".calendar-event-complete-button, .calendar-day-checklist__edit")].map(control => ({
        width: control.getBoundingClientRect().width,
        height: control.getBoundingClientRect().height
      }))
    JS
    assert mobile_controls.all? { |control| control["width"] >= 44 && control["height"] >= 44 }, mobile_controls.inspect
    save_qa_screenshot("calendar-day-dense-mobile.png")
  end

  test "mobile rhythm month renders all recorded states without page overflow" do
    mobile_sign_in
    visit rhythms_path(month: "2026-08")

    assert_mobile_width_without_page_overflow
    assert_selector "[data-rhythm-month='2026-08']"
    %w[full minimum skipped returned].each do |state|
      assert_selector "[data-rhythm-id='#{@rhythm.id}'] [data-rhythm-state='#{state}']"
    end
    assert_text(/Вернулся.*возвращения после пропуска/i)
    page.execute_script("document.documentElement.style.scrollBehavior = 'auto'; arguments[0].scrollIntoView({ block: 'start' })", find("[data-rhythm-id='#{@rhythm.id}'] [data-rhythm-month]"))
    save_qa_screenshot("rhythms-month-mobile.png")
  end

  private

  def mobile_sign_in
    page.driver.browser.manage.window.resize_to(390, 844)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: 390,
      height: 844,
      deviceScaleFactor: 1,
      mobile: true
    )
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

  def assert_mobile_width_without_page_overflow
    assert_equal 390, page.evaluate_script("window.innerWidth")
    overflow = page.evaluate_script("document.documentElement.scrollWidth - window.innerWidth")
    assert_operator overflow, :<=, 1, "page-level horizontal overflow: #{overflow}px"
  end

  def save_qa_screenshot(filename)
    return unless ENV["ECHO_QA_SCREENSHOTS"] == "1"

    directory = Rails.root.join("tmp", "qa")
    FileUtils.mkdir_p(directory)
    page.save_screenshot(directory.join(filename))
  end
end
