﻿
&НаКлиенте
Процедура ЗапроситьИнформациюПоТаблицам(Команда)
	мДанныеПоМесту = ПолучитьДанныеПоМестуНаСервере(фСтрокаСоединения);
	фТаблица.Очистить();
	Если мДанныеПоМесту <> Неопределено Тогда
		Для Каждого мЭлемент Из мДанныеПоМесту Цикл
			мНоваяСтрока = фТаблица.Добавить();
			ЗаполнитьЗначенияСвойств(мНоваяСтрока, мЭлемент);
		КонецЦикла;
	КонецЕсли;
	фТаблица.Сортировать("Всего УБЫВ, Строк УБЫВ, Метаданные");
КонецПроцедуры

&НаСервереБезКонтекста
Функция ПолучитьДанныеПоМестуНаСервере(пСтрокаСоединения)
	мСоединение = Новый ComObject("ADODB.Connection");
	мСоединение.Open(пСтрокаСоединения);
	
	мТекстЗапроса = "SELECT 
	|    t.NAME AS TableName,
	|    s.Name AS SchemaName,
	|    p.rows,
	|    SUM(a.total_pages) * 8 AS TotalSpaceKB, 
	|    CAST(ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS TotalSpaceMB,
	|    SUM(a.used_pages) * 8 AS UsedSpaceKB, 
	|    CAST(ROUND(((SUM(a.used_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS UsedSpaceMB, 
	|    (SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB,
	|    CAST(ROUND(((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024.00, 2) AS NUMERIC(36, 2)) AS UnusedSpaceMB
	|FROM 
	|    sys.tables t
	|INNER JOIN
	|    sys.indexes i ON t.OBJECT_ID = i.object_id
	|INNER JOIN
	|    sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
	|INNER JOIN
	|    sys.allocation_units a ON p.partition_id = a.container_id
	|LEFT OUTER JOIN
	|    sys.schemas s ON t.schema_id = s.schema_id
	|WHERE
	|    t.NAME NOT LIKE 'dt%'
	|    AND t.is_ms_shipped = 0
	|    AND i.OBJECT_ID > 255
	|GROUP BY
	|    t.Name, s.Name, p.Rows
	|ORDER BY
	|    TotalSpaceMB DESC, t.Name";
	
	мЗаписи = Новый ComObject("ADODB.RecordSet");
	мЗаписи.Open(мТекстЗапроса, мСоединение);
	мДанныеПоРазмеруТаблицаСУБД = Новый ТаблицаЗначений;
	мДанныеПоРазмеруТаблицаСУБД.Колонки.Добавить("ИмяТаблицы");
	мДанныеПоРазмеруТаблицаСУБД.Колонки.Добавить("Строк");
	мДанныеПоРазмеруТаблицаСУБД.Колонки.Добавить("Всего");
	мДанныеПоРазмеруТаблицаСУБД.Колонки.Добавить("Занято");
	мДанныеПоРазмеруТаблицаСУБД.Колонки.Добавить("Свободно");
	//мДанныеПоРазмеруТаблицаСУБД.Колонки.Добавить("Метаданные");
	
	
	
	Пока мЗаписи.EOF() = 0 Цикл 
		
		мНоваяСтрока = мДанныеПоРазмеруТаблицаСУБД.Добавить();
		мНоваяСтрока.ИмяТаблицы = мЗаписи.Fields("TableName").Value;
		мНоваяСтрока.Строк = мЗаписи.Fields("rows").Value;
		
		мНоваяСтрока.Всего = мЗаписи.Fields("TotalSpaceMB").Value;
		мНоваяСтрока.Занято = мЗаписи.Fields("UsedSpaceMB").Value;
		мНоваяСтрока.Свободно = мЗаписи.Fields("UnusedSpaceMB").Value;
		
		мЗаписи.MoveNext(); 
	КонецЦикла; 
	
	мЗаписи.Close(); 
	мСоединение.Close(); 
	
	вМассив = Новый Массив;
	мСтруктураТаблиц = ПолучитьСтруктуруХраненияБазыДанных();
	Для Каждого мСтрокаСтруктурыХранения Из мСтруктураТаблиц Цикл
		мИмяТаблицы = "_" + СтрЗаменить(мСтрокаСтруктурыХранения.ИмяТаблицыХранения, ".", "_");
		мЗаписьТаблицыСУБД = мДанныеПоРазмеруТаблицаСУБД.Найти(мИмяТаблицы, "ИмяТаблицы");
		
		Если мЗаписьТаблицыСУБД <> Неопределено Тогда
			мСтруктура = Новый Структура("ИмяТаблицы, Строк, Всего, Занято, Свободно");
			ЗаполнитьЗначенияСвойств(мСтруктура, мЗаписьТаблицыСУБД);
			мСтруктура.Вставить("Метаданные", мСтрокаСтруктурыХранения.Метаданные + " " + мСтрокаСтруктурыХранения.Назначение);
			вМассив.Добавить(мСтруктура);
		КонецЕсли;
	КонецЦикла;
	
	Возврат вМассив;
КонецФункции

&НаСервере
Процедура ПриСозданииНаСервере(Отказ, СтандартнаяОбработка)
	мКонстантаАдрес = Метаданные.Константы.Найти("кcСтрокаSQLпроизводство");
	Если мКонстантаАдрес <> Неопределено Тогда
		фСтрокаСоединения = Константы["кcСтрокаSQLпроизводство"].Получить();
	//ИначеЕсли Метаданные.Константы.Найти("") Тогда
	//	фСтрокаСоединения = Константы["кcСтрокаSQLпроизводство"].Получить();
	Иначе
		фСтрокаСоединения = "Driver={SQL Server};Server=10.11.12.13;Uid=sa;Pwd=PASS;Database=DBNAME;";
	КонецЕсли;
КонецПроцедуры