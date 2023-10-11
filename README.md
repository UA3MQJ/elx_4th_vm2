# elx_4th_vm2

Проект по результатам работы проекта https://github.com/UA3MQJ/elx_4th_vm

Совершив некоторый перерыв в работе над проектом, пришел к выводу, что совершенно позабыл все ключевые ньюансы, которые надо понимать по его работе.

В рамках этого проекта хотелось бы повторить изначальный проект - создание vm для forth, но разработать его именно в последовательном варианте. Постепенно добавляя то, что нужно. А не как в изначальном проекте - добавляя все и сразу, непонятно зачем.

# Проект - "восстановление последовательности"

1. Создаем базовый модуль E4vm. Модуль типа структура. Экземпляр структуры с данными будет состоянием vm. А методы - будут реализовывать изменение состояния.
1.1 Базовые свойства форт системы: rs, ds, ip, wp
```
    rs: Structure.Stack.new(), # Стек возвратов
    ds: Structure.Stack.new(), # Стек данных
    ip: 0,                     # Указатель инструкций
    wp: 0,                     # Указатель слова
```
