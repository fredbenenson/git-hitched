class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :require_invite_code

  helper_method :page_enabled?

  def page_enabled?(page)
    return true if Rails.env.development? && session[:dev_show_all_pages]
    pages_config.fetch(page.to_s, true)
  end

  def pages_config
    PAGES_CONFIG
  end

  private

  def require_invite_code
    return if session[:site_authenticated]

    session[:return_to] = request.fullpath
    redirect_to gate_path
  end

  def require_page_enabled!(page)
    redirect_to root_path unless page_enabled?(page)
  end
end
