module SimplesIdeias
  module Friends
    def self.included(base)
      base.extend SimplesIdeias::Friends::ClassMethods
    end
    
    module ClassMethods
      def has_friends(default_status = 'accepted')
        include SimplesIdeias::Friends::InstanceMethods
        
        has_many :friendships
        has_many :friends, :through => :friendships, :source => :friend, :conditions =>
            ['"friendships".status != "deleted"' +
              (default_status.nil? ? "" :  "AND friendships.status = #{default_status}")]
        has_many :friend_for, :through => :friendships, :source => :user, :conditions =>
            ['"friendships".status != "deleted"' +
              (default_status.nil? ? "" :  "AND friendships.status = #{default_status}")]
        after_destroy :destroy_all_friendships
      end
    end
    
    module InstanceMethods
      def be_friends_with(friend)
        # no user object
        return nil, Friendship::STATUS_FRIEND_IS_REQUIRED unless friend
        
        # should not create friendship if user is trying to add himself
        return nil, Friendship::STATUS_IS_YOU if is?(friend)
        
        # should not create friendship if users are already friends
        return nil, Friendship::STATUS_ALREADY_FRIENDS if friends?(friend)
        
        # retrieve the friendship request
        friendship = self.friendship_for(friend)
        
        # let's check if user has already a friendship request or have removed
        request = friend.friendship_for(self)
        
        # friendship has already been requested
        return nil, Friendship::STATUS_ALREADY_REQUESTED if friendship && friendship.requested?
        
        # friendship is pending so accept it
        if friendship && friendship.pending?
          friendship.accept!
          request.accept!
          
          return friendship, Friendship::STATUS_FRIENDSHIP_ACCEPTED
        end

        # You stole my wife, burnt my house and ruined my company but let's be BFF again
        if friendship && friendship.deleted?
          if request.accepted?
            friendship.update_attribute(:status, request.status)
            friendship.accept!
            return friendship, Friendship::STATUS_FRIENDSHIP_ACCEPTED
          end
           friendship.update_attribute(:status, 'requested')
           return nil, Friendship::STATUS_ALREADY_REQUESTED
        end

        # we didn't find a friendship, so let's create one!
        friendship = self.friendships.create(:friend_id => friend.id, :status => 'requested')

        # we didn't find a friendship request, so let's create it!
        request = friend.friendships.create(:friend_id => id, :status => 'pending')
        
        return friendship, Friendship::STATUS_REQUESTED
      end
      
      def friends?(friend)
        friendship = friendship_for(friend)
        friendship && friendship.accepted?
      end
      
      def friendship_for(friend)
        friendships.first :conditions => {:friend_id => friend.id} if friend
      end
      
      def is?(friend)
        self.id == friend.id
      end

      def remove_friendship(former_friend)
        former_friendship = friendships.first :conditions => {:friend_id => former_friend.id}
        former_friendship.enemies!
      end
      
      private
        def destroy_all_friendships
          Friendship.delete_all({:user_id => id})
          Friendship.delete_all({:friend_id => id})
        end
    end
  end
end