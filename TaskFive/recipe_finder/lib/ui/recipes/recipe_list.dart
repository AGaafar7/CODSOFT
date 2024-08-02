import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_dropdown.dart';
import '../colors.dart';
import '../../network/recipe_model.dart';
import '../recipe_card.dart';
import 'recipe_details.dart';
import 'package:chopper/chopper.dart';
import '../../network/model_response.dart';
import '../../data/models/models.dart';
import '../../network/service_interface.dart';
import 'package:provider/provider.dart';
import 'dart:collection';

class RecipeList extends StatefulWidget {
  const RecipeList({Key? key}) : super(key: key);

  @override
  _RecipeListState createState() => _RecipeListState();
}

class _RecipeListState extends State<RecipeList> {
  //key
  static const String prefSearchKey = 'previousSearches';
  late TextEditingController searchTextController;
  final ScrollController _scrollController = ScrollController();

  //new API Class
  List<APIHits> currentSearchList = [];
  int currentCount = 0;
  int currentStartPosition = 0;
  int currentEndPosition = 20;
  int pageCount = 20;
  bool hasMore = false;
  bool loading = false;
  bool inErrorState = false;
  //searches array
  List<String> previousSearches = <String>[];

  @override
  void initState() {
    super.initState();
    //getPreviousSearches
    getPreviousSearches();
    searchTextController = TextEditingController(text: '');
    _scrollController.addListener(() {
      final triggerFetchMoreSize =
          0.7 * _scrollController.position.maxScrollExtent;

      if (_scrollController.position.pixels > triggerFetchMoreSize) {
        if (hasMore &&
            currentEndPosition < currentCount &&
            !loading &&
            !inErrorState) {
          setState(() {
            loading = true;
            currentStartPosition = currentEndPosition;
            currentEndPosition =
                min(currentStartPosition + pageCount, currentCount);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    searchTextController.dispose();
    super.dispose();
  }

  //savePreviousSearches
  void savePreviousSearches() async {
    //1
    final prefs = await SharedPreferences.getInstance();
    //2
    prefs.setStringList(prefSearchKey, previousSearches);
  }

  //getPreviousSearches
  void getPreviousSearches() async {
    //1
    final prefs = await SharedPreferences.getInstance();
    //2
    if (prefs.containsKey(prefSearchKey)) {
      //3
      final searches = prefs.getStringList(prefSearchKey);
      //4
      if (searches != null) {
        previousSearches = searches;
      } else {
        previousSearches = <String>[];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            _buildSearchCard(),
            _buildRecipeLoader(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: 4,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0))),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            // Replace
            IconButton(
              icon: const Icon(Icons.search),
              //1
              onPressed: () {
                startSearch(searchTextController.text);
                //3
                final currentFocus = FocusScope.of(context);
                if (!currentFocus.hasPrimaryFocus) {
                  currentFocus.unfocus();
                }
              },
            ),
            const SizedBox(
              width: 6.0,
            ),
            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(
                      //3
                      child: TextField(
                    decoration: const InputDecoration(
                        border: InputBorder.none, hintText: 'Search'),
                    autofocus: false,
                    //4
                    textInputAction: TextInputAction.done,
                    //5
                    onSubmitted: (value) {
                      if (!previousSearches.contains(value)) {
                        previousSearches.add(value);
                        savePreviousSearches();
                      }
                    },
                    controller: searchTextController,
                  )),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: lightGrey,
                    ),
                    //7
                    onSelected: (String value) {
                      searchTextController.text = value;
                      startSearch(searchTextController.text);
                    },
                    itemBuilder: (BuildContext context) {
                      //8
                      return previousSearches
                          .map<CustomDropdownMenuItem<String>>((String value) {
                        return CustomDropdownMenuItem<String>(
                          text: value,
                          value: value,
                          callback: () {
                            setState(() {
                              //9
                              previousSearches.remove(value);
                              Navigator.pop(context);
                            });
                          },
                        );
                      }).toList();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //startSearch
  void startSearch(String value) {
    //1
    setState(() {
      //2
      currentSearchList.clear();
      currentCount = 0;
      currentEndPosition = pageCount;
      currentStartPosition = 0;
      hasMore = true;
      value = value.trim();

      //3
      if (!previousSearches.contains(value)) {
        //4
        previousSearches.add(value);
        //5
        savePreviousSearches();
      }
    });
  }

  Widget _buildRecipeLoader(BuildContext context) {
    //1
    if (searchTextController.text.length < 3) {
      return Container();
    }
    //2
    return FutureBuilder<Response<Result<APIRecipeQuery>>>(
      future: Provider.of<ServiceInterface>(context).queryRecipes(
          searchTextController.text.trim(),
          currentStartPosition,
          currentEndPosition),
      //4
      builder: (context, snapshot) {
        //5
        if (snapshot.connectionState == ConnectionState.done) {
          //6
          if (snapshot.hasError) {
            return Center(
              child: Text(snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  textScaler: const TextScaler.linear(1.3)),
            );
          }

          //7
          loading = false;
          //1
          if (false == snapshot.data?.isSuccessful) {
            var errorMessage = 'Problems getting data';
            //2
            if (snapshot.data?.error != null &&
                snapshot.data?.error is LinkedHashMap) {
              final map = snapshot.data?.error as LinkedHashMap;
              errorMessage = map['message'];
            }
            return Center(
              child: Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18.0),
              ),
            );
          }
          //3
          final result = snapshot.data?.body;
          if (result == null || result is Error) {
            //Hit an error
            inErrorState = true;
            return _buildRecipeList(context, currentSearchList);
          }
          //4
          final query = (result as Success).value;
          inErrorState = false;
          if (query != null) {
            currentCount = query.count;
            hasMore = query.more;
            currentSearchList.addAll(query.hits);
            //8
            if (query.to < currentEndPosition) {
              currentEndPosition = query.to;
            }
          }
          //9
          return _buildRecipeList(context, currentSearchList);
        }
        //Handle not done connection
        //10
        else {
          //11
          if (currentCount == 0) {
            //Show loading indicator while waiting for the recipes
            return const Center(child: CircularProgressIndicator());
          } else {
            //12
            return _buildRecipeList(context, currentSearchList);
          }
        }
      },
    );
  }

//_buildRecipeCard
  Widget _buildRecipeCard(
      BuildContext topLevelContext, List<APIHits> hits, int index) {
    //1
    final recipe = hits[index].recipe;
    return GestureDetector(
      onTap: () {
        Navigator.push(topLevelContext, MaterialPageRoute(
          builder: (context) {
            final detailRecipe = Recipe(
                label: recipe.label,
                image: recipe.image,
                url: recipe.url,
                calories: recipe.calories,
                totalTime: recipe.totalTime,
                totalWeight: recipe.totalWeight);
            detailRecipe.ingredients = convertIngredients(recipe.ingredients);
            return RecipeDetails(recipe: detailRecipe);
          },
        ));
      },
      //recipeCard()
      child: recipeCard(recipe),
    );
  }

  //1
  Widget _buildRecipeList(BuildContext recipeListContext, List<APIHits> hits) {
    //2
    final size = MediaQuery.of(context).size;
    const itemHeight = 310;
    final itemWidth = size.width / 2;
    //3
    return Flexible(
      //4
      child: GridView.builder(
        //5
        controller: _scrollController,
        //6
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: (itemWidth / itemHeight),
        ),
        //7
        itemCount: hits.length,
        //8
        itemBuilder: (BuildContext context, int index) {
          return _buildRecipeCard(recipeListContext, hits, index);
        },
      ),
    );
  }
}
