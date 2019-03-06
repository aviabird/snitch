defmodule Snitch.Factory.OptionType do
  defmacro __using__(_opts) do
    quote do
      alias Snitch.Data.Schema.Option

      def option_type_factory do
        %Option{
          name: sequence(:name, &"option-type-#{&1}"),
          display_name: sequence(:display_name, &"display-name-#{&1}")
        }
      end
    end
  end
end
