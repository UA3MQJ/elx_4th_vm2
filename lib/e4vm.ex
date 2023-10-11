defmodule E4vm do
  @moduledoc """
  Documentation for `E4vm`.
  ds word size - 16 bit
  """
  require Logger
  alias Structure.Stack

  defstruct [
    rs: Stack.new(), # Стек возвратов
    ds: Stack.new(), # Стек данных
    ip: 0,           # Указатель инструкций
    wp: 0,           # Указатель слова
    mem: %{},        # память программ
    core: %{},       # Base instructions
    entries: [],     # Core Word header dictionary
    hereP: 0,        # Here pointer
  ]

  def new() do
    %E4vm{}
  end

  # Суть интерпретации заключается в переходе
  # по адресу в памяти и в исполнении инструкции,
  # которая там указана.
  # Останавливаемся, если адрес 0
  def next(%E4vm{ip: 0} = vm), do: vm
  def next(vm) do
    # выбираем адрес следующей инструкции
    next_wp = vm.mem[vm.ip]
    # увеличиваем указатель инструкций
    next_ip = vm.ip + 1
    new_vm = %E4vm{vm | ip: next_ip, wp: next_wp}

    # по адресу следующего указателя на слово
    # выбираем адрес инструкции из памяти
    # и по адресу определяем команду с помощью хранилища примитовов
    {m, f} = vm.core[new_vm.mem[next_wp]]

    # выполняем эту команду
    next_new_vm = apply(m, f, [new_vm])

    # повторяем цикл
    next(next_new_vm)
  end

end
