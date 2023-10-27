defmodule E4vm.Words.CoreExt do
  alias Structure.Stack
  alias E4vm.CoreWord

  def add_core_words(%E4vm{} = vm) do
    vm
    |> E4vm.add_core_word("quit",       __MODULE__, :quit,           false)
    |> E4vm.add_core_word("doLit",      __MODULE__, :do_lit,         false)
    |> E4vm.add_core_word("here",       __MODULE__, :get_here_addr,  false)
    |> E4vm.add_core_word(",",          __MODULE__, :comma,          false)
    |> E4vm.add_core_word("branch",     __MODULE__, :branch,         false)
    |> E4vm.add_core_word("0branch",    __MODULE__, :zbranch,        false)
    |> E4vm.add_core_word("dump",       __MODULE__, :dump,           false)
    |> E4vm.add_core_word("words",      __MODULE__, :words,          false)
    |> E4vm.add_core_word("[",          __MODULE__, :lbrac,          true)
    |> E4vm.add_core_word("]",          __MODULE__, :rbrac,          false)
    |> E4vm.add_core_word("immediate",  __MODULE__, :immediate,      true)
    |> E4vm.add_core_word("execute",    __MODULE__, :execute,        false)
  end

  def quit(_vm) do
    :erlang.halt()
  end

  # Чтобы при интерпретации отличить числовую константу от адреса слова,
  # при компиляции перед каждой константой компилируется вызов слова doLit,
  # которое считывает следующее значение в памяти и размещает его на стеке данных.
  def do_lit(vm) do
    # "ip:#{vm.ip} wp:#{vm.wp}" |> IO.inspect(label: ">>>>>>>>>>>> do_lit ")
    next_ds = Stack.push(vm.ds, vm.mem[vm.ip])
    next_ip = vm.ip + 1

    %E4vm{vm | ip: next_ip, ds: next_ds}
  end

  # поместит в стек данных адрес hereP
  def get_here_addr(vm) do
    # "ip:#{vm.ip} wp:#{vm.wp} here:#{vm.hereP}" |> IO.inspect(label: ">>>>>>>>>>>> here    ")
    next_ds = Stack.push(vm.ds, vm.hereP)

    %E4vm{vm | ds: next_ds}
  end

  # Reserve data space for one cell and store w in the space.
  # просто положит в ячейку на hereP++ число из стека
  def comma(vm) do
    # "ip:#{vm.ip} wp:#{vm.wp}" |> IO.inspect(label: ">>>>>>>>>>>> comma   ")
    # AddOp(DS.Pop());
    {:ok, top_ds}  = Stack.head(vm.ds)
    {:ok, next_ds} = Stack.pop(vm.ds)

    %E4vm{vm | ds: next_ds}
    |> E4vm.add_op(top_ds)
  end

  def tick(vm) do
    # "ip:#{vm.ip} wp:#{vm.wp}" |> IO.inspect(label: ">>>>>>>>>>>> tick    ")

    case E4vm.read_word(vm) do
      {vm, :end} ->
        IO.inspect(label: ">>>> tick NO WORDS")
        vm
      {new_vm, word} ->
        # IO.inspect(word, label: ">>>> interpreter word")
        word_addr = E4vm.look_up_word_address(new_vm, word)
        # IO.inspect(word_addr, label: ">>>> word_addr")
        next_ds = Stack.push(new_vm.ds, word_addr)
        %E4vm{new_vm | ds: next_ds}
    end
  end

  # переход по адресу в следующей ячейке
  def branch(vm) do
    # "ip:#{vm.ip} wp:#{vm.wp}" |> IO.inspect(label: ">>>>>>>>>>>> branch  ")

    next_ip = vm.mem[vm.ip]
    %E4vm{vm | ip: next_ip}
  end

  # переход по адресу, если в след ячейке 0. то есть false.
  # false - это все биты в ноле. true - это все биты одной ячейки(cell) в единице.
  def zbranch(vm) do
    # "ip:#{vm.ip} wp:#{vm.wp}" |> IO.inspect(label: ">>>>>>>>>>>> zbranch ")

    {:ok, top_ds} = Stack.head(vm.ds)
    {:ok, next_ds} = Stack.pop(vm.ds)

    if top_ds==0 do
      # переходим
      # IO.inspect(label: ">>>>>>>>>>>> zbranch переходим")

      # vm |> E4vm.inspect_core()

      next_ip = vm.mem[vm.ip]
      %E4vm{vm | ip: next_ip, ds: next_ds}
    else
      # не переходим
      # IO.inspect(label: ">>>>>>>>>>>> zbranch не переходим")
      %E4vm{vm | ip: vm.ip, ds: next_ds}
    end
  end

  def dump(vm) do
    # "ip:#{vm.ip} wp:#{vm.wp}" |> IO.inspect(label: ">>>>>>>>>>>> dump    ")

    {:ok, size} = Stack.head(vm.ds)
    {:ok, next_ds} = Stack.pop(vm.ds)

    {:ok, start_addr} = Stack.head(next_ds)
    {:ok, next_next_ds} = Stack.pop(next_ds)

    IO.puts("\r\n-----  MEMORY DUMP from addr=#{start_addr} size=#{size} -----\r\n")
    Enum.each(start_addr..start_addr+size, fn(addr) ->
      addr_str = addr
        |> Integer.to_string(16)
        |> String.pad_leading(4, "0")
      data_str = case vm.mem[addr] do
        nil -> 'XX'
        data ->
          Integer.to_string(data, 16)
          |> String.pad_leading(2, "0")
      end

      IO.puts("0x#{addr_str}:#{data_str}")
    end)

    %E4vm{vm | ds: next_next_ds}
  end

  def words(vm) do
    # "ip:#{vm.ip} wp:#{vm.wp}" |> IO.inspect(label: ">>>>>>>>>>>> words   ")

    words = vm.core
      |> :lists.reverse()
      |> Enum.map(fn(word) -> word.word end)
      |> Enum.join(" ")
      # |> IO.inspect(label: ">>>>>>>>>>>> vm   ")

    IO.puts("\r\n#{words}\r\n")
    vm
  end

  # войти в eval режим - eval = true
  def lbrac(vm) do
    # "ip:#{vm.ip} wp:#{vm.wp}" |> IO.inspect(label: ">>>>>>>>>>>> lbrac   ")
    %E4vm{vm | is_eval_mode: true}
  end

  # выйти из eval режима - eval = false
  def rbrac(vm) do
    # "ip:#{vm.ip} wp:#{vm.wp}" |> IO.inspect(label: ">>>>>>>>>>>> rbrac   ")
    %E4vm{vm | is_eval_mode: false}
  end

  # делаем последнее определенное слово immediate = true
  def immediate(vm) do
    [last_word|tail] = vm.core

    new_core = [%CoreWord{last_word | immediate: true}] ++ tail

    %E4vm{vm | core: new_core}
  end

  # выполнить слово по адресу со стека ds - стек данных
  def execute(vm) do
    {:ok, top_ds} = Stack.head(vm.ds)
    {:ok, next_ds} = Stack.pop(vm.ds)

    addr = top_ds

    # length(vm.entries) |> IO.inspect(label: ">>>>>>>>>>>> execute ")

    if addr < vm.entries do
      # слово из core
      {_word, {{m, f}, _immediate, _enable}} = :lists.nth(addr + 1, :lists.reverse(vm.entries))
      next_vm = %E4vm{vm | ds: next_ds}

      apply(m, f, [next_vm])
    else
      # интерпретируемое слово
      %E4vm{vm | ds: next_ds}
    end
  end
end
