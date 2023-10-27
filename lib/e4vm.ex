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
    # channel options
    read_char_mfa: nil,        # {m,f}
    read_char_state: nil,
  ]

  def new() do
    %E4vm{}
      |> E4vm.Words.Core.add_core_words()
      |> E4vm.Words.CoreExt.add_core_words()
      |> E4vm.Words.Stack.add_core_words()
      |> E4vm.Words.Math.add_core_words()
      |> E4vm.Words.Boolean.add_core_words()
      |> E4vm.Words.Comment.add_core_words()
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

  # берет mfa и выполняет. переключаемая логика.
  # read_char_mfa модуль функция, которой передается vm. возврат {new_vm, char}
  # read_char_state использовать для стейта функции чтения. любые данные.
  def read_char(%E4vm{} = vm) do
    {m, f} = vm.read_char_mfa
    {_next_read_char_state, _char} = apply(m, f, [vm.read_char_state])
  end

  def read_string_char_function(read_char_state) do
    case string_char_reader(read_char_state) do
      {:end, _} ->
        {read_char_state, :end}
      {char, next_char_state} ->
        {next_char_state, char}
    end
  end

  def string_char_reader(state) do
    if String.length(state) > 0 do
      <<char>> <> next_state = state
      {<<char>>, next_state} # char это строка, но длиной 1 символ!
    else
      {:end, state}
    end
  end

  def read_word(%E4vm{} = vm) do
    {_next_vm, _word} = do_read_word("", vm)
  end

  def do_read_word(word, vm) do
    case read_char(vm) do
      {next_char_state, :end} ->
        next_vm = %{vm| read_char_state: next_char_state}
        if word == "" do
          {next_vm, :end}
        # иначе возвращаем слово
        else
          {next_vm, word}
        end
      {next_char_state, char} ->
        next_vm = %{vm| read_char_state: next_char_state}
        if char in [" ", "\n", "\r", "\t"] do
          # если пусто, то еще ничего на считали и продолждаем
          if word == "" do
            do_read_word(word, next_vm)
          # иначе возвращаем слово
          else
            {vm, word} # vm, а не next_vm - не выкидываем пробел
          end
        else
          # если символ не пробельный - добавляем
          do_read_word(word <> char, next_vm)
        end
    end
  end
end
