defmodule E4vm do
  defmodule CoreWord do
    defstruct [:word, :module, :function, :address, :immediate, :enabled]
  end
  @moduledoc """
  Documentation for `E4vm`.
  ds word size - 16 bit
  """
  require Logger
  alias Structure.Stack
  alias E4vm.CoreWord

  @alu_bit_width 16

  defstruct [
    rs: Stack.new(), # Стек возвратов
    ds: Stack.new(), # Стек данных
    ip: 0,           # Указатель инструкций
    wp: 0,           # Указатель слова
    mem: %{},        # память программ
    core: [],        # Base instructions
    # entries: [],     # Core Word header dictionary
    hereP: 0,        # Here pointer указатель на адрес, где будет следующее слово
    cell_bit_size: @alu_bit_width, # cell - 16 bit
    is_eval_mode: true,
  ]

  def new() do
    %E4vm{}
      |> E4vm.Words.Core.add_core_words()
      |> E4vm.Words.CoreExt.add_core_words()
      |> E4vm.Words.Stack.add_core_words()
      |> E4vm.Words.Math.add_core_words()
      |> E4vm.Words.Boolean.add_core_words()
  end

  def do_list(vm), do: E4vm.Words.Core.do_list(vm)
  def next(vm), do: E4vm.Words.Core.next(vm)
  def exit(vm), do: E4vm.Words.Core.exit(vm)

  # функция добавления слово в словарь базовых:
  def add_core_word(%E4vm{} = vm, word, module, function, immediate) do
    word_address = vm.hereP
    core_word = %CoreWord{
      word: word,
      module: module,
      function: function,
      address: word_address,
      immediate: immediate,
      enabled: true # by default
    }

    vm
    |> Map.merge(%{core: [core_word] ++ vm.core})
    |> add_address_to_mem(word_address)
    |> inc_here() # hereP++
  end

  # всякий синтаксический сахар

  # hereP++
  def inc_here(%E4vm{} = vm),
    do: %E4vm{vm| hereP: vm.hereP + 1}

  # занести в адрес 1 -> 1
  def add_address_to_mem(%E4vm{} = vm, address) do
    new_mem = Map.merge(vm.mem, %{address => address})
    %E4vm{vm| mem: new_mem}
  end

  # сохранить текущее here в wp чтобы это место считать стартовым для программы
  def here_to_wp(vm) do
    # "ip:#{vm.ip} wp:#{vm.wp}" |> IO.inspect(label: ">>>>>>>>>>>> here->wp")
    %E4vm{vm | wp: vm.hereP}
  end

  # это больше нужно для pipe'ов потому что вложенную фунцию в пайпе не вызвать с входными данными (или можно?)
  # поместить в память адрес слова, найденного по строке
  def add_op_from_string(%E4vm{} = vm, word_string) do
    addr = look_up_word_address(vm, word_string)
    new_mem = Map.merge(vm.mem, %{vm.hereP => addr})
    %E4vm{vm| hereP: vm.hereP + 1, mem: new_mem}
  end

  # добавляем операцию в память. то есть в память по адресу hereP кладем переданный адрес слова
  def add_op(%E4vm{} = vm, addr) do
    new_mem = Map.merge(vm.mem, %{vm.hereP => addr})
    %E4vm{vm| hereP: vm.hereP + 1, mem: new_mem}
  end

  # поиск адреса слова
  def look_up_word_address(vm, word_string) do
    case look_up_word_by_string(vm, word_string) do
      %CoreWord{address: address} -> address
      _else -> :undefined
    end
  end

  # поиск слова по строке
  def look_up_word_by_string(%E4vm{core: core} = _vm, word_string) do
    result = Enum.find(core, fn word -> word.word == word_string end)
    case result do
      %CoreWord{} = core_word -> core_word
      _else -> :undefined
    end
  end

  # поиск слова по адресу
  def look_up_word_by_address(%E4vm{core: core} = _vm, word_address) do
    result = Enum.find(core, fn word -> word.address == word_address end)
    case result do
      %CoreWord{} = core_word -> core_word
      _else -> :undefined
    end
  end
end
