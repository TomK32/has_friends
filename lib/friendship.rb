class Friendship < ActiveRecord::Base
  # constants
  STATUS_ALREADY_FRIENDS     = 1
  STATUS_ALREADY_REQUESTED   = 2
  STATUS_IS_YOU              = 3
  STATUS_FRIEND_IS_REQUIRED  = 4
  STATUS_FRIENDSHIP_ACCEPTED = 5
  STATUS_REQUESTED           = 6

  %w(pending accepted requested deleted).each do |status|
    self.class_eval <<-EOS
      named_scope :#{status}, :conditions => {:status => "#{status}"}
      define_method(:#{status}?) { self.status == "#{status}" }
   EOS
  end
  
  # scopes
  named_scope :active, :conditions => 'friendships.status IS NOT "deleted"'
  
  # associations
  belongs_to :user
  belongs_to :friend, :class_name => 'User', :foreign_key => 'friend_id'
  validates_uniqueness_of :friend_id, :on => :create, :scope => :user_id
  
  # callback
  after_destroy :decrement_friend_count
  def decrement_friend_count
    User.decrement_counter(:friends_count, user_id) #if friend.friend?(user)
  end

  def accept!
    User.increment_counter(:friends_count, user.id) unless accepted?
    update_attribute(:status, 'accepted')
  end

  # unlike a destroy this will keep the record and prevent future friendships requests
  def enemies!
    decrement_friend_count
    self.update_attribute(:status, 'deleted')
  end
end