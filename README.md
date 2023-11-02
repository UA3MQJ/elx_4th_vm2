# elx_4th_vm2

Проект по результатам работы проекта https://github.com/UA3MQJ/elx_4th_vm

Совершив некоторый перерыв в работе над проектом, пришел к выводу, что совершенно позабыл все ключевые ньюансы, которые надо понимать по его работе.

В рамках этого проекта хотелось бы повторить изначальный проект - создание vm для forth, но разработать его именно в последовательном варианте. Постепенно добавляя то, что нужно. А не как в изначальном проекте - добавляя все и сразу, непонятно зачем.

# Проект - "восстановление последовательности"

# 1. базовый модуль E4vm

Создаем базовый модуль E4vm. Модуль типа структура. Экземпляр структуры с данными будет состоянием vm. А методы - будут реализовывать изменение состояния.

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
1.3 операции над элементами стека, математические, логические

Это вот те операции, для реализации которых ничего не надо. То есть они берут данные на стеке, что-то с ними делают и кладут обратно. Их можно реализовать, имея только текущий функционал. Даже помещать данные на стек уметь не надо.

Это операции

Stack: `drop swap dup over rot nrot`

Math: `- + * / mod 1+ 1-`

Boolean: `true false and or xor not invert = <> < > <= >=`

в ядро пришлось добавить `cell_bit_size: @alu_bit_width` ширину АЛУ для определенной разрядности логических слов. и на будущее флаг `is_eval_mode: true`

1.4 добавим еще несколько слов в core_ext

Добавлю еще слова в Core, но чтобы не усложнять базовый Core сделаю CoreExt. Слова которые не требуют реализации и понимания доп возможностей от ядра: `quit`, `doLit`, `here`, `","`, `branch`, `0branch`, `dump`, `words`

Это слова:
 * `quit` для выхода;
 * `doLit` помещение константы в стек;
 * `here` помещение адреса hereP в стек;
 * `,` (comma) Reserve data space for one cell and store w in the space - просто положит в ячейку по адресу hereP число из стека;
 * `branch` переход по адресу в следующей ячейке
 * `0branch` zbranch переход по адресу, если в след ячейке 0. то есть false (false - это все биты в ноле. true - это все биты одной ячейки(cell) в единице.)
 * `dump` - вывод содержимого памяти
 * `words` - вывод списка определенных слов

1.5 добавим слова `[ ]` они меняют свойство ядра `is_eval_mode` при этом, слово `[` добавляется с `immediate==true` что это дает - пока не понятно.

1.6* Похоже, дальше нужно реализовать слова, которые будут читать введенный поток. Для этого реализуем read_char. Чтение одного символа. В свойствах ядра задам две переменные: одна `read_char_mfa: nil, # {m,f}` модуль и функция, которая будет отдавать очередной символ. А вторая переменная `read_char_state: nil,` это состояние (буфер, итд). 

```
  # берет mfa и выполняет. переключаемая логика.
  # read_char_mfa модуль функция, которой передается vm. возврат {new_vm, char}
  # read_char_state использовать для стейта функции чтения. любые данные.
  def read_char(%E4vm{} = vm) do
    {m, f} = vm.read_char_mfa
    {_next_read_char_state, _char} = apply(m, f, [vm.read_char_state])
  end
```

возвращать должно или символ и новый стейт {next_char_state, char} или конец {next_char_state, :end}.

Базовая функция, получения из строки "abcd" таких данных:

```
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
```

и из `read_char` можно сделать абстрактный `read_word`

```
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
```

После этого можно делать слова, использующие `read_char`: например Comment. НО, блин, протестить никак потому что проверка через `EVAL`. Сбой линейной последовательности.

1.7 В принципе, можно с тем, что уже есть, реализовать слова `immediate` -не особо понимая и `execute` в принципе понятно. `Immediate` при выполнении меняет флаг `immediate` у последнего определенного слова на `true`. А `execute` - выполнить слово по адресу со стека ds - стек данных. Выполнить мы вроде бы тоже как можем.

```
  # делаем последнее определенное слово immediate = true
  def immediate(vm) do
    [last_word|tail] = vm.core

    new_core = [%CoreWord{last_word | immediate: true}] ++ tail

    %E4vm{vm | core: new_core}
  end
```
выполнение слова
```
  # выполнить слово по адресу со стека ds - стек данных
  def execute(vm) do
    {:ok, top_ds} = Stack.head(vm.ds)
    {:ok, next_ds} = Stack.pop(vm.ds)

    word_address = top_ds

    case E4vm.look_up_word_by_address(vm, word_address) do
      # слова нет в core - значит оно интерпретируется
      :undefined ->
        # интерпретируемое слово
        %E4vm{vm | ds: next_ds}
      core_word ->
        next_vm = %E4vm{vm | ds: next_ds}

        apply(core_word.module, core_word.function, [next_vm])
    end
  end
```

1.7 eval(interpreter(interpreter_word()))

После реализации `eval` начали работать тесты через `eval` для `math_test`, `comment_test`, 

`mem_test` работает, но не проходит - надо реализовать слова.

`rw_test` - то же самое.

1.8


2 Промежуточный итог.

Ядро имеет `rs`, `ds`, `ip`, `wp`, память `mem`, хранилище примитивов `core`. Базовые операции `doList`, `next`, `exit` позволяют выполнять программу. Добавлены другие слова, которые не требуют ничего дополнительно от ядра, кроме свойства `cell_bit_size` - размер базовой ячейки, который нужен для формирования правильных констант boolean.

Для удобства работы и тестов добавлены utils, в которых есть функции `ds2to1op` и `ds1to1op` для синтаксического сахара и более короткой записи реализации манипуляций над словами на стеке. Функция для тестов `ds_push` для прмещения произвольного числа на стек данных и `ds_pop` для получения числа с топа стека данных. Формирование константы `true` и `false` на основе `cell_bit_size` (to_bool_const). inspect_core - для вывода на экран полного состояния ядра.

Хранилище слов Core - это список структур типа CoreWord. Там есть поле `immediate` которое пока всегда `false` и будет использоваться позже. Для удобства работы с хранилищем, созданы и применяются функции `add_core_word` для добавления слова в хранилище. `inc_here` - просто увеличение указателя `hereP` в режиме построения теста в виде elixir pipe без создания промежуточных переменных. Функция `add_address_to_mem(address)` просто по адресу занисит его же значение - что-то типа базовой таблицы в памяти. 

Функция `here_to_wp` опять же для тестов - поместить текущий `hereP` в `WP`. Старт выполнения программы начинается с адреса в `wp`, а каждое добавление слова в память - смещает `hereP` вниз. И если после добавления слов ядра сохранить `hereP` в `WP`, и дальше добавлять слова уже программы, то `WP` будет указывать на адрес начала именно программы. После чего можно просто запускать выполнение. Тупо удобство синтаксического определения и наполнения состояния VM для тестов.

Функция `add_op_from_string` - это больше нужно для pipe'ов потому что вложенную фунцию в пайпе не вызвать с входными данными (или можно?) поместить в память адрес слова, найденного по строке.

Функция `add_op` - добавляем операцию в память. то есть в память по адресу hereP кладем переданный адрес слова. Используется в `add_op_from_string`

Функции поиска слова в хранилище Core: `look_up_word_by_address` найти полное описание слова по адресу; `look_up_word_by_string` найти полное описание слова по строковому определению слова "," (описание comma); `look_up_word_address` на базе двух ранее описанных слов, ищет описание слова по строке и возвращает адрес.

Добавлены слова `[ ]` тупо меняют свойство `is_eval_mode` у машины.

Добавлено слово `immediate` - меняет флаг `immediate` в `true` у последнего определенного слова.

Добавлено слово `execute` - выполнить слово по адресу со стека ds - стек данных. Если слово есть в `core` то исполняется, иначе интерпретируется благодаря `doList`.

Готовы внутренние функции и возможности для `read_char` и `read_word` - можно двигаться дальше.

Делаем интерпретатор. Зависимости:

```
eval(interpreter, read_char)
interpreter(read_word, interpreter_word)
read_word(do_read_word(read_char))
interpreter_word(execute, is_constant, add_op, add_op_from_string)
```
Возможно, стоит сделать полное дерево зависимостей.


# Поддежка слов

- [x] Core: `nop next doList exit`
- [ ] Ext Core: `quit doLit here , branch 0branch dump words [ ] immediate execute` TODO: `: ; '`
- [x] Mem: `! @ variable constant`
- [x] Stack: `drop swap dup over rot nrot`
- [x] Math: `- + * / mod 1+ 1-`
- [x] Boolean: `true false and or xor not invert = <> < > <= >=`
- [x] Comment: `( \\`
- [ ] RW: `. .s cr bl word s" key`
