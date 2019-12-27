#include "mainwindow.h"
#include "ui_mainwindow.h"
#include <QtSql/qsqlquery.h>
MainWindow::MainWindow(QWidget *parent) :
    QMainWindow(parent),
    ui(new Ui::MainWindow)
{
    ui->setupUi(this);
}

MainWindow::~MainWindow()
{
    delete ui;
}

void MainWindow::on_pushButton_clicked()
{
    QSqlDatabase db = QSqlDatabase::addDatabase("QPSQL");
    db.setHostName("127.0.0.1");
    db.setDatabaseName("mydb");
    db.setUserName("postgres");
    db.setPassword("experimental");
    db.setPort(5432);
    db.open();
    if(db.open()) {
        QSqlQuery query("SELECT * from customers" , db);

        QSqlQuery q2("SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE table_catalog = 'mydb'  AND table_name = 'customers'" , db);
        q2.first();
        QSqlQuery q3("SELECT count(*) from customers" , db);
        QSqlQuery q4("SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE table_catalog = 'mydb'  AND table_name = 'customers'" , db);
        q3.first();
        q4.first();
        bool ok1;
        ui->tableWidget->setRowCount(q3.value(0).toInt(&ok1));
        bool ok2;
        ui->tableWidget->setColumnCount(q2.value(0).toInt(&ok2));
        QList<QString> labels;
        for(int i = 0 ; i < ui->tableWidget->columnCount() ; i++){
            labels.push_back(q4.value(3).toString());
            q4.next();
        }
        ui->tableWidget->setHorizontalHeaderLabels(QStringList(labels));
        int row = 0;
        bool hasnext = query.next();
        while(hasnext){
            for(int col = 0 ; col < ui->tableWidget->columnCount(); col++){
                QTableWidgetItem* item = new QTableWidgetItem();
                item->setText(query.value(col).toString());
                ui->tableWidget->setItem(row , col ,item);
            }
            row++;
            hasnext = query.next();
        }
        db.close();
    }


}

void MainWindow::on_pushButton_2_clicked()
{
    QSqlDatabase db = QSqlDatabase::addDatabase("QPSQL");
    db.setHostName("127.0.0.1");
    db.setDatabaseName("mydb");
    db.setUserName("postgres");
    db.setPassword("experimental");
    db.setPort(5432);
    db.open();
    if(db.open()) {
        QSqlQuery query("SELECT * from books" , db);

        QSqlQuery q2("SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE table_catalog = 'mydb'  AND table_name = 'books'" , db);
        q2.first();
        QSqlQuery q3("SELECT count(*) from books" , db);
        QSqlQuery q4("SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE table_catalog = 'mydb'  AND table_name = 'books'" , db);
        q3.first();
        q4.first();
        bool ok1;
        ui->tableWidget->setRowCount(q3.value(0).toInt(&ok1));
        bool ok2;
        ui->tableWidget->setColumnCount(q2.value(0).toInt(&ok2));
        QList<QString> labels;
        for(int i = 0 ; i < ui->tableWidget->columnCount() ; i++){
            labels.push_back(q4.value(3).toString());
            q4.next();
        }
        ui->tableWidget->setHorizontalHeaderLabels(QStringList(labels));
        int row = 0;
        bool hasnext = query.next();
        while(hasnext){
            for(int col = 0 ; col < ui->tableWidget->columnCount(); col++){
                QTableWidgetItem* item = new QTableWidgetItem();
                item->setText(query.value(col).toString());
                ui->tableWidget->setItem(row , col ,item);
            }
            row++;
            hasnext = query.next();
        }
        db.close();
    }

}

void MainWindow::on_pushButton_3_clicked()
{
    QSqlDatabase db = QSqlDatabase::addDatabase("QPSQL");
    db.setHostName("127.0.0.1");
    db.setDatabaseName("mydb");
    db.setUserName("postgres");
    db.setPassword("experimental");
    db.setPort(5432);
    db.open();
    if(db.open()) {
        QSqlQuery query("SELECT * from orders" , db);
        QSqlQuery q2("SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE table_catalog = 'mydb'  AND table_name = 'orders'" , db);
        QSqlQuery q3("SELECT count(*) from orders" , db);
        QSqlQuery q4("SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE table_catalog = 'mydb'  AND table_name = 'orders'" , db);
        q2.first();
        q3.first();
        q4.first();
        bool ok1;
        ui->tableWidget->setRowCount(q3.value(0).toInt(&ok1));
        bool ok2;
        ui->tableWidget->setColumnCount(q2.value(0).toInt(&ok2));
        QList<QString> labels;
        for(int i = 0 ; i < ui->tableWidget->columnCount() ; i++){
            labels.push_back(q4.value(3).toString());
            q4.next();
        }
        ui->tableWidget->setHorizontalHeaderLabels(QStringList(labels));
        int row = 0;
        bool hasnext = query.next();
        while(hasnext){
            for(int col = 0 ; col < ui->tableWidget->columnCount(); col++){
                QTableWidgetItem* item = new QTableWidgetItem();
                item->setText(query.value(col).toString());
                ui->tableWidget->setItem(row , col ,item);
            }
            row++;
            hasnext = query.next();
        }
        db.close();
    }


}
