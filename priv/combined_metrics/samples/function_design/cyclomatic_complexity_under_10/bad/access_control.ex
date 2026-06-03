defmodule AccessControl do
  def authorize(user, resource, action) do
    if user.role == :admin do
      :ok
    else
      if user.role == :owner && resource.owner_id == user.id do
        :ok
      else
        if user.role == :member do
          if action == :read do
            if resource.shared_user_ids != nil && user.id in resource.shared_user_ids do
              :ok
            else
              {:error, :forbidden}
            end
          else
            if action == :write && :edit in user.permissions do
              if resource.locked == true do
                {:error, :locked}
              else
                :ok
              end
            else
              {:error, :forbidden}
            end
          end
        else
          if user.role == :guest && action == :read do
            :ok
          else
            {:error, :forbidden}
          end
        end
      end
    end
  end
end
