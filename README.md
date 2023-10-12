# elx_4th_vm2

Проект по результатам работы проекта https://github.com/UA3MQJ/elx_4th_vm

Совершив некоторый перерыв в работе над проектом, пришел к выводу, что совершенно позабыл все ключевые ньюансы, которые надо понимать по его работе.

В рамках этого проекта хотелось бы повторить изначальный проект - создание vm для forth, но разработать его именно в последовательном варианте. Постепенно добавляя то, что нужно. А не как в изначальном проекте - добавляя все и сразу, непонятно зачем.

# Проект - "восстановление последовательности"

# 1. Создаем базовый модуль E4vm. Модуль типа структура. Экземпляр структуры с данными будет состоянием vm. А методы - будут реализовывать изменение состояния.
## 1.1 Базовые свойства форт системы: rs, ds, ip, wp
```
    rs: Structure.Stack.new(), # Стек возвратов
    ds: Structure.Stack.new(), # Стек данных
    ip: 0,                     # Указатель инструкций
    wp: 0,                     # Указатель слова
```
## 1.2 Адресный интерпретатор. Определение трех базовых слов.

добавляем память и хранилище базовых слов
```
    mem: %{},                  # память программ
    core: %{},                 # Base instructions
    entries: [],               # Core Word header dictionary
    hereP: 0,                  # Here pointer указатель на адрес, где будет следующее слово
```
В памяти храним адреса команд.

Суть интерпретации заключается в переходе по адресу в памяти и в исполнении слова, которая там указана.
```
  # Останавливаемся, если адрес 0
  def next(%E4vm{ip: 0} = vm) do
    vm
  end
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
```

В core хранятся указания, как исполнять базовые слова.

Слова в список базовых добавляются через `add_core_word`
```
# первый параметр - слово
# второй параметр - {модуль, функция}
# третий параметр - immediate (признак немедленного исполнения)
E4vm.add_core_word("hello2",  {CoreTest, :hello},   false)

```

функция добавления слово в словарь базовых:

```
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
    |> Map.merge(%{word_address => word_address})
    |> inc_here() # hereP++
  end
```
После добавления слова:
```
E4vm.add_core_word("hello2",  __MODULE__, :hello,   false)
```
В списке слов `core` будет находиться запись, с информацией, что слово "hello2" выполняется определенным модулем и определенной функцией, что оно immediate=false, а так же адрес этого слова.
При этом, в память `mem` будет занесен код операции. В адресе 0 будет код 0. В адресе 1 код 1. Как бы таблица адресов базовых инструкций, где адрес и код совпадают и они не выполняются последовательно, а являются вызовами двоичных модулей самой виртуальной машины. Чуть позже будет определение по типа слова (встроенное/пользовательское) по адресу.

Для минимальной работы интерпретатора, достаточно определить 3 слова:

```
  def add_core_words(%E4vm{} = vm) do
    vm
    |> E4vm.add_core_word("doList",    __MODULE__, :do_list,        false)
    |> E4vm.add_core_word("next",      __MODULE__, :next,           false)
    |> E4vm.add_core_word("exit",      __MODULE__, :exit,           false)
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

```


