defmodule E4vm.Test do
  use ExUnit.Case

  test "step 1.2 simple start test" do
    Process.register(self(), :test_proc)

    E4vm.new()
      # добавляем слова
      |> E4vm.add_core_word("hello",  __MODULE__, :hello,   false)
      # hereP -> wp - с этого места будет начинаться прогамма
      |> E4vm.here_to_wp()
      |> E4vm.add_op_from_string("doList")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("hello")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("exit")
      |> E4vm.do_list()
      |> E4vm.next()
      # |> IO.inspect(label: ">>>> vm")

    assert_receive :hello
  end

  test "step 1.2 call/return simple start test" do
    Process.register(self(), :test_proc)

    vm = E4vm.new()
      # добавляем слова
      |> E4vm.add_core_word("hello",  __MODULE__, :hello,   false)

    # адрес начала подпрограммы
    sub_word_address = vm.hereP

    vm
      # подпрограмма
      |> E4vm.add_op_from_string("doList")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("hello")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("exit")
      # hereP -> wp - с этого места будет начинаться прогамма
      |> E4vm.here_to_wp()
      |> E4vm.add_op_from_string("doList")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op(sub_word_address)
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("exit")
      # |> IO.inspect(label: ">>>> vm")
      |> E4vm.do_list()
      |> E4vm.next()
      # |> IO.inspect(label: ">>>> vm")

    assert_receive :hello
  end

  def nop(vm) do
    "ip:#{vm.ip} wp:#{vm.wp}" |> IO.inspect(label: ">>>>TEST>>>> nop  ")
    vm
  end

  def hello(vm) do
    "ip:#{vm.ip} wp:#{vm.wp}" |> IO.inspect(label: ">>>>TEST>>>> hello  ")

    IO.puts("Hello test")

    send(:test_proc, :hello)

    vm
  end
end
