# frozen_string_literal: true
class ApplicationController < ActionController::Base
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::TextHelper
  include PageRedirectConcern
  include CommentsHelper
  include CommentsFormHelper
  include TagsHelper
  include MostFocusHelper

  protect_from_forgery with: :exception
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :if_not_signed_in, unless: :devise_controller?
  before_action :set_sentry_context, if: proc { Rails.env.production? }
  before_action :set_locale
  around_action :with_timezone

  private

  def with_timezone
    timezone = Time.find_zone(cookies[:timezone])
    Time.use_zone(timezone) { yield }
  end

  def set_locale
    @locale = I18n.locale = locale
    @locales = Rails.application.config.i18n.available_locales
  end

  def configure_permitted_parameters
    common = %i[location name email password
                password_confirmation current_password]
    configure_for_account_update(common)
    configure_for_sign_up(common)
    configure_for_accept_invitation
  end

  def set_sentry_context
    Sentry.set_user(id: current_user.id) if user_signed_in?
    Sentry.set_extras(params: params.to_unsafe_h, url: request.url)
  end

  def locale
    current_user&.locale || cookies[:locale] || I18n.default_locale
  end

  def configure_for_account_update(common)
    devise_parameter_sanitizer.permit :account_update,
                                      keys: %i[about avatar
                                               remove_avatar comment_notify
                                               ally_notify group_notify
                                               meeting_notify] + common
  end

  def configure_for_sign_up(common)
    devise_parameter_sanitizer.permit :sign_up, keys: common
  end

  def configure_for_accept_invitation
    devise_parameter_sanitizer.permit :accept_invitation,
                                      keys: %i[name password
                                               password_confirmation
                                               invitation_token]
  end

  def after_sign_in_path_for(resource)
    if resource.respond_to?(:pwned?) && resource.pwned?
      cookies[:pwned] = { value: true, expires: Time.current + 10.minutes }
    end

    super
  end
end
