module Admin
  class GuestsController < BaseController
    before_action :set_guest, only: [ :show, :edit, :update, :destroy ]

    def index
      base = Guest.includes(:invite)
                  .joins(:invite)
                  .where(invites: { linked_invite_id: nil })
                  .order("invites.name ASC, guests.is_primary DESC, guests.first_name ASC")

      case params[:filter]
      when "children"      then base = base.children
      when "childcare"     then base = base.where(needs_childcare: true)
      when "missing_email" then base = base.adults.where(email: [ nil, "" ])
      end

      base = base.where("guests.first_name ILIKE :q OR guests.last_name ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?

      @attending = base.where(invites: { attending: true }).where.not(invites: { responded_at: nil })
      @pending   = base.where(invites: { responded_at: nil })
      @declined  = base.where(invites: { attending: false })
    end

    def show
    end

    def new
      @guest = Guest.new
    end

    def create
      @guest = Guest.new(guest_params)
      if @guest.save
        redirect_to admin_guest_path(@guest), notice: "Guest created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @guest.update(guest_params)
        respond_to do |format|
          format.html { redirect_to admin_guest_path(@guest), notice: "Guest updated." }
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              helpers.dom_id(@guest),
              partial: "admin/guests/guest_row",
              locals: { guest: @guest }
            )
          end
        end
      else
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_entity }
          format.turbo_stream { head :unprocessable_entity }
        end
      end
    end

    def destroy
      @guest.destroy
      redirect_to admin_guests_path, notice: "Guest deleted."
    end

    private

    def set_guest
      @guest = Guest.find(params[:id])
    end

    def guest_params
      params.require(:guest).permit(:invite_id, :first_name, :last_name, :email, :is_primary, :is_child, :needs_childcare, :needs_highchair, :reception_seating, :age, :meal_choice, :dietary_notes)
    end
  end
end
