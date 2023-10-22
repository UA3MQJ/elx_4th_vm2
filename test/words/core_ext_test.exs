defmodule E4vm.Words.CoreExtTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  test "test doLit" do
    vm = E4vm.new()
      |> E4vm.here_to_wp()
      |> E4vm.add_op_from_string("doList")
      |> E4vm.add_op_from_string("doLit")
      |> E4vm.add_op(555)
      |> E4vm.add_op_from_string("exit")
      |> E4vm.Words.Core.do_list()
      |> E4vm.Words.Core.next()
      # |> IO.inspect(label: ">>>> vm")

    assert "#Stack<[555]>" == inspect(vm.ds)
  end

  test "test here" do
    vm = E4vm.new()
      |> E4vm.here_to_wp()
      |> E4vm.add_op_from_string("doList")
      |> E4vm.add_op_from_string("here")
      |> E4vm.add_op_from_string("exit")
      |> E4vm.Words.Core.do_list()
      |> E4vm.Words.Core.next()
      # |> E4vm.inspect_core()

    top_ds = vm |> E4vm.Utils.ds_pop()
    assert vm.hereP == top_ds
  end

  test "test comma" do
    vm = E4vm.new()
      |> E4vm.here_to_wp()
      |> E4vm.add_op_from_string("doList")
      |> E4vm.add_op_from_string(",")

    vm = vm
      |> E4vm.Utils.ds_push(0)
      |> E4vm.add_op_from_string("exit")

    vm = vm
      |> E4vm.Words.Core.do_list()
      |> E4vm.Words.Core.next()

    assert vm.mem[vm.hereP - 1] == 0
  end

  test "test branch" do
    Process.register(self(), :test_proc)

    vm = E4vm.new()
      |> E4vm.add_core_word("hello2", __MODULE__, :hello, false)
      |> E4vm.here_to_wp()

    vm = vm
      |> E4vm.add_op_from_string("doList")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("branch")

    jmp_address = vm.hereP

    vm
      |> E4vm.add_op(jmp_address + 4)      # перепрыгнет через hello2. а если +2 перепрыгнет на hello2
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("hello2")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("exit")
      |> E4vm.Words.Core.do_list()
      |> E4vm.Words.Core.next()
      # |> IO.inspect(label: ">>>> vm")

    refute_receive :hello

    vm
      |> E4vm.add_op(jmp_address + 2)      # перепрыгнет через hello2. а если +2 перепрыгнет на hello2
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("hello2")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("exit")
      |> E4vm.Words.Core.do_list()
      |> E4vm.Words.Core.next()
      # |> IO.inspect(label: ">>>> vm")

    assert_receive :hello
  end

  test "test zbranch" do
    Process.register(self(), :test_proc)

    vm = E4vm.new()
      |> E4vm.add_core_word("hello2", __MODULE__, :hello,   false)
      |> E4vm.here_to_wp()

    vm = vm
      |> E4vm.add_op_from_string("doList")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("0branch")
      |> E4vm.Utils.ds_push(0)

    jmp_address = vm.hereP

    vm
      |> E4vm.add_op(jmp_address + 4)      # перепрыгнет через hello2
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("hello2")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("exit")
      |> E4vm.Words.Core.do_list()
      |> E4vm.Words.Core.next()
      # |> IO.inspect(label: ">>>> vm")

    refute_receive :hello

    # -------------
    IO.puts("\r\n")

    vm = E4vm.new()
    |> E4vm.add_core_word("hello2", __MODULE__, :hello, false)
    |> E4vm.here_to_wp()

    vm = vm
      |> E4vm.add_op_from_string("doList")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("0branch")
      |> E4vm.Utils.ds_push(1)

    jmp_address = vm.hereP

    vm
      |> E4vm.add_op(jmp_address + 4)      # не перепрыгнет через hello2
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("hello2")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("nop")
      |> E4vm.add_op_from_string("exit")
      |> E4vm.Words.Core.do_list()
      |> E4vm.Words.Core.next()
      # |> E4vm.inspect_core()

    assert_receive :hello
  end

  test "test dump" do
    E4vm.new()
      |> E4vm.here_to_wp()
      |> E4vm.add_op_from_string("doList")
      |> E4vm.add_op_from_string("doLit")
      |> E4vm.add_op(0)
      |> E4vm.add_op_from_string("here")
      |> E4vm.add_op_from_string("dump")
      |> E4vm.add_op_from_string("exit")
      |> E4vm.Words.Core.do_list()
      |> E4vm.Words.Core.next()
  end

  test "test words" do
    E4vm.new()
      |> E4vm.here_to_wp()
      |> E4vm.add_op_from_string("doList")
      |> E4vm.add_op_from_string("words")
      |> E4vm.add_op_from_string("exit")
      |> E4vm.Words.Core.do_list()
      |> E4vm.Words.Core.next()
  end

  test "test ]" do
    vm = E4vm.new()
      |> E4vm.here_to_wp()
      |> E4vm.add_op_from_string("doList")
      |> E4vm.add_op_from_string("]")
      |> E4vm.add_op_from_string("exit")
      |> E4vm.Words.Core.do_list()
      |> E4vm.Words.Core.next()

      assert vm.is_eval_mode == false
  end

  test "test ] [" do
    vm = E4vm.new()
      |> E4vm.here_to_wp()
      |> E4vm.add_op_from_string("doList")
      |> E4vm.add_op_from_string("]")
      |> E4vm.add_op_from_string("[")
      |> E4vm.add_op_from_string("exit")
      |> E4vm.Words.Core.do_list()
      |> E4vm.Words.Core.next()

      assert vm.is_eval_mode == true
  end

  def hello(vm) do
    "ip:#{vm.ip} wp:#{vm.wp}" |> IO.inspect(label: ">>>>TEST>>>> hello  ")

    IO.puts("Hello test")

    send(:test_proc, :hello)

    vm
  end
end
