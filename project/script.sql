--Скрипт для создания БД и таблиц для проекта "Личный кабинет потребителя электроэнергии"

DROP DATABASE IF EXISTS EPW_OTUS;
GO

--ASK Файловые группы пока по наитию, и больше, чтобы попробовать, возможно, стоит пересмотреть
CREATE DATABASE EPW_OTUS
ON PRIMARY
--В основном, справочная информация, небольшие редко изменяемые, но часто читаемые таблички
--Можно разместить на SSD
--Без ограничений на размер
( NAME = EPWAppData,
    FILENAME = 'D:\EPW_OTUS\EPWAppData.mdf',
    SIZE = 10MB,
    FILEGROWTH = 1MB ),
--Временные ряды (почасовые, получасовые интервалы). Хранение исходных данных для проведения расчетов и построения аналитики
--Это может быть не SSD, лишь бы большой
--ASK Не очень понял про MAXSIZE, я так понимаю, нужно следить за заполнением этих файлов, и добавлять новые в файловую группу по мере использования существующих?
--В будущем таблицы из этой файловой группы ждет секционирование по месяцам, пока не знаю как предусмотреть
FILEGROUP RAW_FG
( NAME = SeriesRaw001,
    FILENAME = 'D:\EPW_OTUS\EPWRawData001.ndf',
    SIZE = 100MB,
    MAXSIZE = 500MB,
    FILEGROWTH = 50MB),
( NAME = SeriesRaw002,
    FILENAME = 'D:\EPW_OTUS\EPWRawData002.ndf',
    SIZE = 100MB,
    MAXSIZE = 500MB,
    FILEGROWTH = 50MB),
--Временные ряды для аналитики, обновление раз в месяц, читаем часто, лучше на SSD
--Все аналогично предыдущей файловой группе
FILEGROUP OLAP_FG
( NAME = SeriesOlap001,
    FILENAME = 'D:\EPW_OTUS\EPWOlapData001.ndf',
    SIZE = 100MB,
    MAXSIZE = 500MB,
    FILEGROWTH = 50MB),
( NAME = SeriesOlap002,
    FILENAME = 'D:\EPW_OTUS\EPWOlapData002.ndf',
    SIZE = 100MB,
    MAXSIZE = 500MB,
    FILEGROWTH = 50MB)
--Модель будет SIMPLE, не нужно хранить все изменения во временных рядах, их очень много. Может, и меньше лога хватит
--Не знаю, есть ли смысл переносить на другой диск
LOG ON
( NAME = EPWLog,
    FILENAME = 'D:\EPW_OTUS\EPWLog.ldf',
    SIZE = 10MB,
    MAXSIZE = 100MB,
    FILEGROWTH = 1MB );
GO

USE EPW_OTUS;
GO

--TODO Добавить описания полей в стиле EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Numeric ID used for reference to an order within the database' , @level0type=N'SCHEMA',@level0name=N'Sales', @level1type=N'TABLE',@level1name=N'Orders', @level2type=N'COLUMN',@level2name=N'OrderID'
--     Может, даже получится вытянуть их на клиенте для хинтов, например
--TODO Сделать схемы (в зависимости от модуля клиентского приложения, например)
--TODO Реализовать историчность справочных данных для всех основных сущностей (например, клиента не удаляем, а помечаем как неактивным, или определяем срок действия)

--Клиенты (юридические лица - потребители ЭЭ)
--TODO Предусмотреть работу с физическими лицами тоже (может, отдельная таблица с единым sequence для генерации ключей)
CREATE TABLE CUSTOMER (
 CustomerID int IDENTITY(1,1)
,INN varchar(12) NOT NULL
,Name nvarchar(100) NOT NULL
,CONSTRAINT PK_Customer PRIMARY KEY CLUSTERED (CustomerID ASC)
,CONSTRAINT UQ_INN UNIQUE NONCLUSTERED (INN ASC) 
) ON [PRIMARY];

--TODO Сделать таблицы с ролями и разрешениями (для приложения-клиента). Возможно, создать роли в БД и связать еще с ними

--Пользователи, могут быть привязаны к организации (клиенту), либо нет (обслуживающий персонал)
--TODO Предусмотреть поля (или еще как) с учетом того, что есть люди, для которых не нужен логин
CREATE TABLE PERSON (
 PersonID int IDENTITY(1,1)
,UserLogin nvarchar(20) NOT NULL
,Passsword nvarchar(20) NOT NULL
,EMail nvarchar(30) NOT NULL --ASK где нужен nvarchar, а где varchar. И нормально ли их смешивать в одной таблице, базе
,ExpiresWhen datetime NOT NULL DEFAULT (DATEADD(year, 1, GETDATE()))
,CONSTRAINT PK_Person PRIMARY KEY CLUSTERED (PersonID ASC)
,CONSTRAINT UQ_UserLogin UNIQUE NONCLUSTERED (UserLogin ASC) 
,CONSTRAINT UQ_EMail UNIQUE NONCLUSTERED (EMail ASC) 
) ON [PRIMARY];

--Один пользователь может просматривать данные по нескольким клиентам с разным уровнем доступа (роли потом)
--ASK Интересно, нужен ли здесь первичный ключ типа PerCustID. Может, на клиенте для апдейтов?
CREATE TABLE PERCUST (
 PersonID int NOT NULL
,CustomerID int NOT NULL
,CONSTRAINT FK_PerCust_Person FOREIGN KEY(PersonID) REFERENCES PERSON (PersonID)
,CONSTRAINT FK_PerCust_Customer FOREIGN KEY(CustomerID) REFERENCES CUSTOMER (CustomerID)
,CONSTRAINT UQ_PerCust UNIQUE CLUSTERED (PersonID ASC, CustomerID ASC) --ASC Нормально? Пока не определился с PRIMARY KEY
) ON [PRIMARY];

--Договоры потребителей с энергосбытовой компанией
--TODO Справочник типов договоров (независимая СК может выступать как потребитель). А, может, роли: покупатель и продавец. Тогда еще таблица с продавцами нужна.
--Пока из предположения, что энергосбытовая компания для всех потребителей одна
CREATE TABLE СONTRACT (
 ContractID int IDENTITY(1,1) NOT NULL
,CustomerID int NOT NULL
,ContractNum nvarchar(50) NOT NULL
,ContractDate datetime NOT NULL
,CONSTRAINT PK_Contract PRIMARY KEY CLUSTERED (ContractID ASC)
,CONSTRAINT FK_Contract_Customer FOREIGN KEY(CustomerID) REFERENCES CUSTOMER (CustomerID)
,CONSTRAINT UQ_CustContr UNIQUE NONCLUSTERED (CustomerID ASC, ContractNum ASC)
) ON [PRIMARY];

--Объекты энергоснабжения, входящие в договор
--TODO Добавить справочник ценовых категорий и другие, расширить состав атрибутов
CREATE TABLE OBJECT ( --ASK Если имя зарезервировано (студия выделяет синим), можно ли его использовать, если очень хочется?
 ObjectID int IDENTITY(1,1) NOT NULL
,ContractID int NOT NULL
,ObjNum nvarchar(50) NOT NULL
,ObjName nvarchar(200) NULL
,ObjAddress nvarchar(max) NULL
,CONSTRAINT PK_Object PRIMARY KEY CLUSTERED (ObjectID ASC)
,CONSTRAINT FK_Object_Contract FOREIGN KEY(ContractID) REFERENCES СONTRACT (ContractID)
,CONSTRAINT UQ_ContrObj UNIQUE NONCLUSTERED (ContractID ASC, ObjNum ASC)
) ON [PRIMARY];

--Точки учета, входящие в объект
--TODO Добавить справочник способов ввода данных для точек (дист. сбор данных, ввод показаний вручную)
CREATE TABLE POINT (
 PointID int IDENTITY(1,1) NOT NULL
,ObjectID int NOT NULL
,PointNum int NOT NULL
,PointPlace nvarchar(150) NOT NULL
,RCoef int NOT NULL
,LossPerc decimal(18, 3) NOT NULL
,CONSTRAINT PK_Point PRIMARY KEY CLUSTERED (PointID ASC)
,CONSTRAINT FK_Point_Object FOREIGN KEY(ObjectID) REFERENCES OBJECT (ObjectID)
,CONSTRAINT UQ_ObjPoint UNIQUE NONCLUSTERED (ObjectID ASC, PointNum ASC)
) ON [PRIMARY];

--ASK Понял, что после занятия не хватает каких-то best practices по именованию объектов БД, подглядывал в WideWorldImporters