defmodule E4vm do
  @moduledoc """
  Documentation for `E4vm`.
  ds word size - 16 bit
  """
  require Logger
  alias Structure.Stack

  defstruct [
    rs: Structure.Stack.new(), # Стек возвратов
    ds: Structure.Stack.new(), # Стек данных
    ip: 0,                     # Указатель инструкций
    wp: 0,                     # Указатель слова
  ]

  def new() do
    %E4vm{}
  end

end
