module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      # Optional: Add authentication if needed
      # self.current_user = find_verified_user
      # For anonymous connections (like our auth flow), we can skip authentication
    end

    private

    def find_verified_user
      # Add user authentication logic here if needed in the future
      # For now, we allow anonymous connections for the auth flow
      nil
    end
  end
end
