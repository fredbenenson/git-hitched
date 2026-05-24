module Admin
  class InvitesController < BaseController
    before_action :set_invite, only: [ :show, :edit, :update, :destroy, :link, :toggle_reminder ]

    def index
      @invites = Invite.includes(:guests, :linked_invite).order(:name)

      if params[:status].present?
        @invites = @invites.joins("LEFT OUTER JOIN invites parent_invites ON parent_invites.id = invites.linked_invite_id")
        case params[:status]
        when "attending" then @invites = @invites.where("COALESCE(parent_invites.attending, invites.attending) = ?", true)
        when "declined"  then @invites = @invites.where("COALESCE(parent_invites.attending, invites.attending) = ?", false)
        when "responded" then @invites = @invites.where("COALESCE(parent_invites.responded_at, invites.responded_at) IS NOT NULL")
        when "pending"   then @invites = @invites.where("COALESCE(parent_invites.responded_at, invites.responded_at) IS NULL")
        end
      end

      @invites = @invites.where("invites.name ILIKE :q OR invites.email ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
    end

    def show
      @guests = @invite.guests.order(:last_name, :first_name)
      @events = @invite.events.order(:date)
    end

    def notes
      @invites = Invite.where.not(notes: [ nil, "" ]).includes(:guests).order(responded_at: :desc)
    end

    def new
      @invite = Invite.new
      @invite.guests.build(is_primary: true)
    end

    def create
      @invite = Invite.new(invite_params)
      if @invite.save
        redirect_to admin_invite_path(@invite), notice: "Invite created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @invite.update(invite_params)
        redirect_to admin_invite_path(@invite), notice: "Invite updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @invite.destroy
      redirect_to admin_invites_path, notice: "Invite deleted."
    end

    def search
      query = params[:q].to_s.strip
      return render json: [] if query.length < 2

      scope = Invite
        .where.not(responded_at: nil)
        .where(linked_invite_id: nil)
      scope = scope.where.not(id: params[:exclude_id]) if params[:exclude_id].present?
      scope = scope.where("name ILIKE :q OR email ILIKE :q", q: "%#{query}%")

      render json: scope.order(:name).limit(10).pluck(:id, :name, :email).map { |id, name, email|
        { id: id, name: name, email: email }
      }
    end

    def link
      target_id = params[:linked_invite_id].presence
      @invite.update(linked_invite_id: target_id)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(@invite, :link_cell),
            partial: "admin/invites/link_cell",
            locals: { invite: @invite }
          )
        end
      end
    end

    def toggle_reminder
      @invite.update(send_reminder: ActiveModel::Type::Boolean.new.cast(params[:send_reminder]))
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(@invite, :reminder_cell),
            partial: "admin/invites/reminder_cell",
            locals: { invite: @invite }
          )
        end
      end
    end

    private

    def set_invite
      @invite = Invite.find(params[:id])
    end

    def invite_params
      params.require(:invite).permit(:name, :email,
        guests_attributes: [ :id, :first_name, :last_name, :is_primary, :meal_choice, :dietary_notes, :_destroy ])
    end
  end
end
