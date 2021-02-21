--1. ��������� �������� ������, ������� � ���������� ������ ���������� ��������� ������� ���������� ����:
---�������� �������
---�������� ���������� �������
---
---�������� ����� � ID 2-6, ��� ��� ������������� Tailspin Toys
---��� ������� ����� �������� ��� ����� �������� ������ ���������
---�������� �������� Tailspin Toys (Gasport, NY) - �� �������� � ����� ������ Gasport,NY
---���� ������ ����� ������ dd.mm.yyyy �������� 25.12.2019
---
---��������, ��� ������ ��������� ����������:
---InvoiceMonth Peeples Valley, AZ Medicine Lodge, KS Gasport, NY Sylvanite, MT Jessie, ND
---01.01.2013 3 1 4 2 2
---01.02.2013 7 3 4 2 1

/*
--�������� ����� �������� ��� ����������� � ������ � PIVOT
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
,'�������' InvoiceFact
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

---2. ��� ���� �������� � ������, � ������� ���� Tailspin Toys
---������� ��� ������, ������� ���� � �������, � ����� �������
---
---������ �����������
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

---3. � ������� ����� ���� ���� � ����� ������ �������� � ���������
---�������� ������� �� ������, ��������, ��� - ����� � ���� ��� ���� �������� ���� ��������� ���
---������ ������
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

---4. �������� �� ������� ������� 2 ����� ������� ������, ������� �� �������
---� ����������� ������ ���� �� ������, ��� ��������, �� ������, ����, ���� �������

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

---5. Code review (�����������). ������ �������� � ��������� Hometask_code_review.sql.
---��� ������ ������?
---��� ����� �������� CROSS APPLY - ����� �� ������������ ������ ��������� �������\�������?

/*
������ �� �����-�� ������� ��������������� �������� �������
�� ����� ����� �������� ����� Folder � Directory, ��, ������, Folder ������� �� Directory
������ ���� ������ (���� ��������� ������� RowNum = 1) ���� � ��������� ������ Directory, �������������� �� ������ �������� Folder.
������ ���� �� ������ ���� �� ����� �����-���� ���������, � ����� ���������������.
��������� CROSS APPLY ����� �������� �� ��������� ��� INNER JOIN � vwFolderHistoryRemove, ������ ������� GROUP BY ��� MAX(DirVersionId)
������ EXISTS ������ �� �����.
��, � ��������� ��� NOT EXISTS ����� ��������, �� ������� ����, ��� ���������� :)
*/