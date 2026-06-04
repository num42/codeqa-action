defmodule Billing.QuotaMonitor do
  @moduledoc """
  Quota monitoring — BAD: status booleans built from nested conditionals that
  return true/false instead of being assigned from the comparison directly.
  """

  def status(account) do
    over_limit =
      if account.usage > account.quota do
        true
      else
        false
      end

    near_limit =
      cond do
        over_limit -> false
        account.usage >= account.quota * 0.9 -> true
        true -> false
      end

    suspended =
      case account.status do
        :suspended -> true
        _ -> false
      end

    %{over_limit: over_limit, near_limit: near_limit, suspended: suspended}
  end

  def billing_flags(invoice) do
    is_paid =
      if invoice.status == :paid do
        true
      else
        false
      end

    is_overdue =
      if invoice.due_date_passed do
        if not is_paid do
          true
        else
          false
        end
      else
        false
      end

    %{paid: is_paid, overdue: is_overdue}
  end
end
