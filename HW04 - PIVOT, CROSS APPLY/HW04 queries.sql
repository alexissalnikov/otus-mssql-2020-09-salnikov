--1. Требуется написать запрос, который в результате своего выполнения формирует таблицу следующего вида:
---Название клиента
---МесяцГод Количество покупок
---
---Клиентов взять с ID 2-6, это все подразделение Tailspin Toys
---имя клиента нужно поменять так чтобы осталось только уточнение
---например исходное Tailspin Toys (Gasport, NY) - вы выводите в имени только Gasport,NY
---дата должна иметь формат dd.mm.yyyy например 25.12.2019
---
---Например, как должны выглядеть результаты:
---InvoiceMonth Peeples Valley, AZ Medicine Lodge, KS Gasport, NY Sylvanite, MT Jessie, ND
---01.01.2013 3 1 4 2 2
---01.02.2013 7 3 4 2 1

/*
--получаем имена клиентов для копирования в запрос с PIVOT
;with t (CustomerNameNew) AS
(select
 distinct SUBSTRING(c.CustomerName, charindex('(',c.CustomerName) + 1, len(c.CustomerName) - charindex('(',c.CustomerName) - 1) CustomerNameNew
from Sales.Customers c
where c.CustomerID between 2 and 6
)
select '[' + string_agg(CONVERT(NVARCHAR(max),CustomerNameNew), '], [') within group (order by CustomerNameNew) + ']'
from t
*/

select InvoiceDateF, [Gasport, NY], [Jessie, ND], [Medicine Lodge, KS], [Peeples Valley, AZ], [Sylvanite, MT]
from
(
select
 i.InvoiceDate
,convert(char(10),i.InvoiceDate,104) InvoiceDateF
,SUBSTRING(c.CustomerName, charindex('(',c.CustomerName) + 1, len(c.CustomerName) - charindex('(',c.CustomerName) - 1) CustomerNameNew
,'Покупка' InvoiceFact
from Sales.Customers c
left join Sales.Invoices i on c.CustomerID = i.CustomerID
where c.CustomerID between 2 and 6
) t
PIVOT
(
 count(InvoiceFact)
 FOR CustomerNameNew in ([Gasport, NY], [Jessie, ND], [Medicine Lodge, KS], [Peeples Valley, AZ], [Sylvanite, MT])
) as piv
order by InvoiceDate

---2. Для всех клиентов с именем, в котором есть Tailspin Toys
---вывести все адреса, которые есть в таблице, в одной колонке
---
---Пример результатов
---CustomerName AddressLine
---Tailspin Toys (Head Office) Shop 38
---Tailspin Toys (Head Office) 1877 Mittal Road
---Tailspin Toys (Head Office) PO Box 8975
---Tailspin Toys (Head Office) Ribeiroville

select CustomerName, AddressLine
FROM
(
select
 CustomerName, DeliveryAddressLine1, DeliveryAddressLine2, PostalAddressLine1, PostalAddressLine2
from Sales.Customers c
where c.CustomerName like '%Tailspin Toys%'
) t
UNPIVOT
(
 AddressLine
 FOR AddressLineType in (DeliveryAddressLine1, DeliveryAddressLine2, PostalAddressLine1, PostalAddressLine2)
) as upvt
order by CustomerName, AddressLineType;

---3. В таблице стран есть поля с кодом страны цифровым и буквенным
---сделайте выборку ИД страны, название, код - чтобы в поле был либо цифровой либо буквенный код
---Пример выдачи
---
---CountryId CountryName Code
---1 Afghanistan AFG
---1 Afghanistan 4
---3 Albania ALB
---3 Albania 8

select CountryID, CountryName, Code
from
(
select CountryID, CountryName, cast(IsoAlpha3Code as nvarchar(max)) IsoAlpha3CodeStr, cast (IsoNumericCode as nvarchar(max)) IsoNumericCodeStr
from Application.Countries
) t
UNPIVOT
(
 Code
 FOR CodeType in (IsoAlpha3CodeStr,IsoNumericCodeStr)
) AS upvt
order by CountryID, CodeType

---4. Выберите по каждому клиенту 2 самых дорогих товара, которые он покупал
---В результатах должно быть ид клиета, его название, ид товара, цена, дата покупки

select
 c1.CustomerID
,c1.CustomerName
,exp2.StockItemID
--,exp2.StockItemName
,exp2.UnitPrice
,exp2.InvoiceDateLast
from
Sales.Customers c1
CROSS APPLY
(
select TOP 2
 c.CustomerID
,c.CustomerName
,si.StockItemID
--,si.StockItemName
,si.UnitPrice
,max(i.InvoiceDate) InvoiceDateLast
from Sales.Customers c
left join Sales.Invoices i on c.CustomerID = i.CustomerID
inner join Sales.InvoiceLines il on i.InvoiceID = il.InvoiceID
inner join Warehouse.StockItems si on il.StockItemID = si.StockItemID
where c.CustomerID = c1.CustomerID
group by c.CustomerID, c.CustomerName, si.StockItemID, si.StockItemName, si.UnitPrice
order by si.UnitPrice desc
) exp2
order by CustomerID, UnitPrice desc

---5. Code review (опционально). Запрос приложен в материалы Hometask_code_review.sql.
---Что делает запрос?
---Чем можно заменить CROSS APPLY - можно ли использовать другую стратегию выборки\запроса?

/*
Похоже на какую-то систему версионирования файловой системы
Не очень понял различие между Folder и Directory, но, похоже, Folder состоит из Directory
Запрос ищет первый (если правильно понимаю RowNum = 1) файл в последней версии Directory, существовавшей на момент удаления Folder.
Причём файл не должен быть из числа когда-либо удаленных, а затем восстановленных.
Подзапрос CROSS APPLY можно заменить на подзапрос для INNER JOIN к vwFolderHistoryRemove, только сделать GROUP BY для MAX(DirVersionId)
Первый EXISTS станет не нужен.
Ну, а последние два NOT EXISTS можно оставить, по крайней мере, они читабельны :)
*/