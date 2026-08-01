class SettingsController < ApplicationController
  def show
    @user = current_user
  end

  def update
    @user = current_user
    attrs = settings_params
    quiet_start = attrs.delete(:quiet_start).to_s
    quiet_end = attrs.delete(:quiet_end).to_s

    validate_timezone(attrs[:timezone])
    next_settings = (@user.settings || {}).dup
    apply_quiet_hours(next_settings, quiet_start, quiet_end)
    attrs[:settings] = next_settings

    if @user.errors.any?
      @user.assign_attributes(attrs)
      return render :show, status: :unprocessable_entity
    end

    if @user.update(attrs)
      redirect_to settings_path, notice: "Настройки сохранены"
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.require(:user).permit(:timezone, :language, :quiet_start, :quiet_end)
  end

  def validate_timezone(timezone)
    TZInfo::Timezone.get(timezone.to_s)
  rescue TZInfo::InvalidTimezoneIdentifier
    @user.errors.add(:timezone, "неизвестна")
  end

  def apply_quiet_hours(settings, quiet_start, quiet_end)
    if quiet_start.blank? && quiet_end.blank?
      settings.delete("quiet_start")
      settings.delete("quiet_end")
      return
    end

    unless valid_clock?(quiet_start) && valid_clock?(quiet_end)
      @user.errors.add(:settings, "quiet hours должны быть парой времени HH:MM")
      return
    end

    settings["quiet_start"] = quiet_start
    settings["quiet_end"] = quiet_end
  end

  def valid_clock?(value)
    match = value.match(/\A(\d{2}):(\d{2})\z/)
    match && match[1].to_i.between?(0, 23) && match[2].to_i.between?(0, 59)
  end
end
