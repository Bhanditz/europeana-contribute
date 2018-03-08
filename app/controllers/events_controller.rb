# frozen_string_literal: true

class EventsController < ApplicationController
  before_action :authorize_user!

  def index
    @events = EDM::Event.all
  end

  def new
    @event = EDM::Event.new
    formify_event(@event)
  end

  def create
    @event = EDM::Event.new
    @event.assign_attributes(event_params)

    if @event.valid?
      @event.save
      redirect_to action: :index, c: 'eu-migration'
    else
      formify_event(@event)
      render action: :new, status: 400
    end
  end

  def edit
    @event = EDM::Event.find_by(uuid: params[:uuid])
    formify_event(@event)
    render action: :new
  end

  def update
    @event = EDM::Event.find_by(uuid: params[:uuid])
    @event.assign_attributes(event_params)

    if @event.valid?
      @event.save
      redirect_to action: :index, c: 'eu-migration'
    else
      formify_event(@event)
      render action: :new, status: 400
    end
  end

  private

  def formify_event(event)
    event.build_edm_happenedAt unless event.edm_happenedAt.present?
    event.build_edm_occurredAt unless event.edm_occurredAt.present?
  end

  def event_params
    params.require(:edm_event).permit(
      [
        :skos_prefLabel, {
          edm_happenedAt_attributes: :skos_prefLabel,
          edm_occurredAt_attributes: %i(edm_begin edm_end)
        }
      ]
    )
  end

  def authorize_user!
    authorize! :manage, EDM::Event
  end
end
