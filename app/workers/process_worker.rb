class ProcessWorker
  include Sidekiq::Worker

  PUBLIC_COLLECTION = 'https://www.w3.org/ns/activitystreams#Public'

  def perform(actor, body)
    @actor = actor
    @body  = body
    @json  = Oj.load(@body, mode: :null)

    if follow?
      subscribe!
    elsif unfollow?
      unsubscribe!
    elsif valid_for_rebroadcast?
      pass_through!
    end
  end

  private

  def follow?
    @json['type'] == 'Follow'
  end

  def unfollow?
    @json['type'] == 'Undo' && @json['object']['type'] == 'Follow'
  end

  def valid_for_rebroadcast?
    signed? && addressed_to_public? && supported_type?
  end

  def signed?
    @json['signature'].present?
  end

  def addressed_to_public?
    (Array(@json['to']) + Array(@json['cc'])).include?(PUBLIC_COLLECTION)
  end

  def subscribe_to_public?
    if @json['object'].is_a?(Hash)
      @json['object']['id'] == PUBLIC_COLLECTION
    else
      @json['object'] == PUBLIC_COLLECTION
    end
  end

  def supported_type?
    !(Array(@json['type']) & %w(Create Update Delete Announce Undo)).empty?
  end

  def subscribe!
    return unless subscribe_to_public?

    subscription   = Subscription.find_by(domain: domain)
    subscription ||= Subscription.new(domain: domain)
    subscription.inbox_url = @actor['inbox']
    subscription.save
  end

  def unsubscribe!
    Subscription.where(domain: domain).delete_all
  end

  def pass_through!
    Subscription.where.not(domain: domain).find_each do |subscription|
      DeliverWorker.perform_async(subscription.inbox_url, @body)
    end
  end

  def domain
    @domain ||= Addressable::URI.parse(@actor['id']).normalized_host
  end
end
