defmodule E4vm.Words.Core do
  alias Structure.Stack

  def add_core_words(%E4vm{} = vm) do
    vm
    |> E4vm.add_core_word("nop",       __MODULE__, :nop,            false)
    |> E4vm.add_core_word("doList",    __MODULE__, :do_list,        false)
    |> E4vm.add_core_word("next",      __MODULE__, :next,           false)
    |> E4vm.add_core_word("exit",      __MODULE__, :exit,           false)
  end

  # нет операции
  def nop(vm) do
    # "ip:#{vm.ip} wp:#{vm.wp}" |> IO.inspect(label: ">>>>>>>>>>>> nop    ")
    vm
  end

  # Каждое пользовательское слово начинается с команды DoList,
  # задача которой — сохранить текущий адрес интерпретации на стеке
  # и установить адрес интерпретации следующего слова.
  def do_list(vm) do
    next_rs = Stack.push(vm.rs, vm.ip)
    next_ip = vm.wp + 1

    %E4vm{vm | ip: next_ip, rs: next_rs}
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
    word = E4vm.look_up_word_by_address(new_vm, new_vm.mem[next_wp])

    # выполняем эту команду
    next_new_vm = apply(word.module, word.function, [new_vm])

    # повторяем цикл
    next(next_new_vm)
  end

  # команда для выхода из слова
  # восстанавливает адрес указателя инструкций IP со стека возвратов RS
  def exit(vm) do
    {:ok, next_ip} = Stack.head(vm.rs)
    {:ok, next_rs} = Stack.pop(vm.rs)

    %E4vm{vm | ip: next_ip, rs: next_rs}
  end

end
