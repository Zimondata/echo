require "test_helper"

class PwaEntryTest < ActionDispatch::IntegrationTest
  test "logged-out root opens owner login while the public showcase stays explicit" do
    get root_path

    assert_response :success
    assert_select "title", text: "Вход - Echo"
    assert_not_includes response.body, "Мой AI-ассистент в Telegram"

    get showcase_path
    assert_response :success
    assert_select "title", text: "Echo — Personal AI Assistant in Telegram"
  end

  test "public showcase advertises the app manifest and redirects installed launches to login" do
    get showcase_path

    assert_response :success
    assert_select "link[rel='manifest'][href='#{pwa_manifest_path}']", count: 1
    assert_select "link[rel='apple-touch-icon'][href='/apple-touch-icon.png'][sizes='180x180']", count: 1
    assert_select "meta[name='apple-mobile-web-app-capable'][content='yes']", count: 1
    assert_select "meta[name='apple-mobile-web-app-title'][content='Echo']", count: 1
    script = css_select("script[data-showcase-pwa-entry]").first
    assert script
    assert_includes script.text, "navigator.standalone"
    assert_includes script.text, "display-mode: standalone"
    assert_includes script.text, "location.replace(\"/login\")"
  end

  test "manifest launches the owner login inside standalone mode" do
    get pwa_manifest_path

    assert_response :success
    manifest = response.parsed_body
    assert_equal "Echo", manifest.fetch("name")
    assert_equal "Echo", manifest.fetch("short_name")
    assert_equal "/login", manifest.fetch("start_url")
    assert_equal "standalone", manifest.fetch("display")
    assert_equal [ "/icon-512.png", "/icon-maskable-512.png" ], manifest.fetch("icons").map { |icon| icon.fetch("src") }
  end

  test "owner login advertises the manifest and apple home screen metadata" do
    get root_path

    assert_select "link[rel='manifest'][href='#{pwa_manifest_path}']", count: 1
    assert_select "link[rel='apple-touch-icon'][href='/apple-touch-icon.png'][sizes='180x180']", count: 1
    assert_select "meta[name='apple-mobile-web-app-title'][content='Echo']", count: 1
  end

  test "home screen icon assets have the declared dimensions" do
    assert_equal [ 180, 180 ], png_dimensions(Rails.root.join("public/apple-touch-icon.png"))
    assert_equal [ 512, 512 ], png_dimensions(Rails.root.join("public/icon-512.png"))
    assert_equal [ 512, 512 ], png_dimensions(Rails.root.join("public/icon-maskable-512.png"))
  end

  private

  def png_dimensions(path)
    File.binread(path, 24).byteslice(16, 8).unpack("N2")
  end
end
