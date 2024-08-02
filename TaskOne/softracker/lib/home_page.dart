import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:softracker/components/expense_summary.dart';
import 'package:softracker/components/expense_tile.dart';
import 'package:softracker/data/expense_data.dart';
import 'package:softracker/expense_item.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final newExpenseNameController = TextEditingController();
  final newExpenseDollarController = TextEditingController();
  final newExpenseCentsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Provider.of<ExpenseData>(context, listen: false).prepareData();
  }

  void addNewExpense() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add new Expense"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newExpenseNameController,
              decoration: const InputDecoration(
                hintText: "Expense Name",
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: newExpenseDollarController,
                    decoration: const InputDecoration(
                      hintText: "Dollars",
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: newExpenseCentsController,
                    decoration: const InputDecoration(
                      hintText: "Cents",
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          MaterialButton(
            onPressed: save,
            child: const Text('Save'),
          ),
          MaterialButton(
            onPressed: cancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void deleteExpense(ExpenseItem expense) {
    Provider.of<ExpenseData>(context, listen: false).deleteExpense(expense);
  }

  void save() {
    if (newExpenseNameController.text.isNotEmpty &&
        newExpenseDollarController.text.isNotEmpty &&
        newExpenseCentsController.text.isNotEmpty) {
      String amount =
          '${newExpenseDollarController.text}.${newExpenseCentsController.text}';
      ExpenseItem newExpense = ExpenseItem(
          name: newExpenseNameController.text,
          amount: amount,
          dateTime: DateTime.now());
      Provider.of<ExpenseData>(context, listen: false)
          .addNewExpense(newExpense);
    }
    Navigator.pop(context);
    clear();
  }

  void cancel() {
    Navigator.pop(context);
    clear();
  }

  void clear() {
    newExpenseNameController.clear();
    newExpenseDollarController.clear();
    newExpenseCentsController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseData>(
      builder: (context, value, child) => Scaffold(
        backgroundColor: Colors.grey[300],
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.black,
          onPressed: addNewExpense,
          child: const Icon(Icons.add),
        ),
        body: ListView(
          children: [
            ExpenseSummary(
              startOfWeek: value.startOfWeekDate(),
            ),
            const SizedBox(
              height: 20,
            ),
            ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: value.getAllExpenseList().length,
                itemBuilder: (context, index) => ExpenseTile(
                      name: value.getAllExpenseList()[index].name,
                      amount: value.getAllExpenseList()[index].amount,
                      dateTime: value.getAllExpenseList()[index].dateTime,
                      deleteTapped: (p0) => deleteExpense(
                        value.getAllExpenseList()[index],
                      ),
                    )),
          ],
        ),
      ),
    );
  }
}
