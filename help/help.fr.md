# Aide de l’éditeur

## Éditeur

### Démarrer un projet
Pour créer un projet, vous devez d’abord choisir un dossier de projet dans lequel la séquence narrative sera enregistrée sous forme de fichiers `.json`.
Chaque projet doit commencer par un nœud `root`, qui définit les langues et, si nécessaire, les variables de l’histoire.
Ce nœud racine ne peut contenir que les définitions de variables, les langues, et se terminer par une balise `->` menant vers le premier nœud de l’histoire.

### Nœuds
Un nœud (« knot ») est une scène, qui possède un nom et contient différents blocs d’instructions, comme des dialogues et des instructions de code.
En pratique, chaque nœud correspond à un fichier `.json` enregistré dans le dossier de votre projet et chargé dans le jeu.
Consultez les sections d’aide sur le langage Inkmin pour comprendre comment rédiger le contenu des nœuds.

### Blocs
Dans un nœud, l’histoire est constituée de lignes d’instructions narratives : du texte brut à afficher, des choix, les conséquences de choix, des conditions avec conséquences, des signaux pour le code du jeu ou des commentaires.
L’éditeur affiche ces blocs dans un format simple et lisible, mais ils sont transformés en interne en instructions enregistrées dans les fichiers `.json`, y compris leurs traductions.
Lorsqu’une ligne est simplement du texte brut, le jeu la lit comme du texte brut. Lorsqu’elle commence par une balise telle que `#`, `+` ou `-`, ces balises donnent des instructions au code du jeu.

### Système de fichiers
L’éditeur attend un dossier de projet contenant `root.json` et les autres fichiers de nœuds. Vous devez toujours choisir un seul dossier qui contient tous ces fichiers JSON.
Charger un projet consiste à sélectionner le fichier `root.json` correspondant. Créer un projet consiste à choisir un dossier vide ou dédié dans lequel l’éditeur peut créer le fichier `root.json` et les autres fichiers de nœuds.

### Disposition de l’éditeur
Le panneau de gauche affiche la structure du projet et liste les nœuds. Les nœuds peuvent y être organisés en groupes, mais cela n’a aucune conséquence sur le code du jeu : cela sert uniquement à améliorer la lisibilité.
Le panneau central est l’éditeur de texte dans lequel le scénario est écrit, comme dans un éditeur de texte ordinaire.
Le panneau de droite simule le jeu afin de tester le scénario ; il affiche également les variables dans sa partie inférieure.

### Langues
Il existe une langue principale, qui peut être modifiée, et des langues de traduction, en lecture seule. Cette distinction préserve toutes les instructions destinées au code dans la langue principale.
Si rien n’est précisé, l’anglais (`en`) est la langue par défaut du scénario. D’autres langues peuvent être indiquées dans le nœud racine.
Le gestionnaire de traductions peut exporter un fichier `.tsv` pour travailler dans un tableur, confier les traductions à une autre personne, puis les réimporter dans les fichiers `.json`.
Les traductions peuvent aussi être réalisées directement en cliquant sur le bouton situé à côté de chaque ligne après avoir choisi une langue autre que la langue principale.

### Créateur de scénario
Le créateur de scénario est un éditeur auxiliaire distinct pour préparer des graphes de scénario. Consultez l’onglet d’aide Créateur de scénario pour plus de détails.

### Convertisseur Ink
Les boutons d’export et d’import Ink tentent d’exporter un fichier texte unique contenant l’ensemble du scénario.
Cela peut servir de sauvegarde ou permettre l’utilisation du scénario dans d’autres systèmes de jeu. L’import nécessite d’abord de choisir un dossier de projet ; il créera ensuite tous les fichiers JSON dans ce dossier.
Attention, il est possible que certains transferts d'information ne se fassent pas parfaitement car inkmin et ink ne sont pas parfaitement transposables.

## Langage Inkmin

### Structure de base d’un scénario
Tous les nœuds commencent par un en-tête dont le nom est placé entre les balises `===`.

Exemple :
```text
=== scene 1 ===
```
Le nom du nœud est toujours requis lors de sa création. Il peut être modifié en cliquant sur le bouton à côté de son nom.

Le premier nœud est toujours nommé `=== root ===` et son contenu est limité aux métadonnées.
Par exemple, ce nœud `root` définit l’anglais comme langue principale, le français comme langue de traduction et une valeur initiale pour la variable `score`, puis redirige vers le premier nœud de l’histoire, `intro` :

```text
=== root ===
# LANG=en,fr
# VAR score = 0
-> intro
```

### Lignes de texte brut
Toute ligne qui n’est précédée d’aucune balise est une ligne de texte brut. Le jeu la traite alors selon le code du jeu, par exemple en l’affichant à l’écran sous forme de dialogue ou de texte simple.
Il s’agit du comportement par défaut pour tout texte qui n’est précédé d’aucune balise reconnue.

### Choix
Les lignes qui commencent par la balise `+` créent des choix. Davantage de balises `+` indiquent un rang de choix plus profond.

Exemple :
```text
+ this is my first choice
  ++ this is a subchoice that comes after my first choice
+ this is my second choice
```

### Sections
Les sections (« stitches ») sont des sections nommées à l’intérieur d’un nœud. Commencez une section avec `= nom_de_section` ; elle peut contenir les mêmes blocs narratifs qu’un nœud. Dirigez vers une section du même nœud avec `-> nom_de_section`, ou vers une section d’un autre nœud avec `-> nom_du_nœud.nom_de_section`. Les noms de section doivent être uniques au sein de leur nœud.

### Enchaînements
Les lignes qui commencent par la balise `-` sont des lignes d’enchaînement (« weave »). Elles servent à créer une conséquence finale commune à toutes les branches de choix. Après plusieurs choix et leurs conséquences, la ligne d’enchaînement crée une nouvelle instruction dans le flux narratif qui clôt la phase de choix. Elle peut être suivie d’une ou plusieurs lignes d’instructions ou de texte brut.

Exemple :
```text
+ choice 1
  consequence 1
+ choice 2
  consequence 2
-
consequence of both choice 1 and choice 2
```

### Redirections
Les lignes qui commencent par `-> "destination"` redirigent vers le nœud de destination. Cela permet de naviguer d’un nœud à l’autre.

### Signaux
Les lignes qui commencent par la balise `# "instruction"` émettent un signal auquel le code du jeu peut réagir. La nature de l’instruction dépend de chaque jeu et doit être implémentée dans son code.
Cela ne peut produire un effet que si la syntaxe attendue par le code du jeu est respectée.

Exemple :
```text
# playsound : dingdong
```

### Variables
Les variables doivent être définies dans le nœud racine, par exemple `# VAR variable = 0`. Les valeurs peuvent être des entiers, des nombres décimaux, des booléens (`true` et `false`) ou des chaînes de caractères (du texte simple).
Les noms des variables ne sont sensibles ni à la casse ni aux accents. Lors de l’enregistrement des fichiers JSON, Inkmin les écrit en majuscules sans accents latins : `activité` devient `ACTIVITE`. Le texte de l’histoire et les valeurs des chaînes conservent leurs accents.
Le gestionnaire de variables applique aussi cette conversion et enregistre les fichiers JSON modifiés lors de la vérification du projet.
Les variables peuvent ensuite être manipulées dans d’autres nœuds à l’aide d’opérations simples utilisant la balise `~`.

Exemple :
```text
~ variable = 0
~ variable = variable + 1
```

### Commentaires
Les lignes qui commencent par `// blablabla` sont des commentaires et sont ignorées par le code du jeu.

### Conditions
Les conditions utilisent la forme `{condition:conséquence}`. L’éditeur prend également en charge les conséquences sur plusieurs lignes.
Pour exiger des conditions cumulatives, écrivez-les dans une seule expression de condition avec `&&` : `{condition_1 && condition_2: conséquence}`.
Les conditions acceptées sont des comparaisons mathématiques : `=`, `<` ou `>`.
Les conséquences acceptées sont : du texte, une redirection, une modification de variable ou des choix.

Exemple :
```text
{myvariable = 0 : my variable is empty}
```
ou
```text
{myvariable = 0 :
my variable is empty
this is a second line
}
```

## Implémentation

Le dépôt GitHub d'Inkmin, à l'adresse `https://github.com/instellis/inkmin`, contient le code source de l'éditeur et un exemple d'intégration dans Godot. Le script du lecteur, la scène d'exemple et les fichiers JSON mentionnés dans ce chapitre se trouvent tous dans son dossier `samples/` ; les chemins commençant par `samples/` sont relatifs à la racine de ce dépôt.

### Ajouter le lecteur Inkmin à un jeu Godot

- Copiez `samples/inkminreader.gd` depuis le dépôt ainsi que les fichiers JSON produits par Inkmin dans votre projet Godot. Placez `root.json` et tous les fichiers JSON des nœuds dans un même dossier.
- Ajoutez un `Node` à la scène du jeu et attachez-lui le script `inkminreader.gd`. Le script analyse les fichiers JSON pendant l'exécution et émet un signal nommé `inkminfeed` contenant un dictionnaire pour chaque événement narratif.
- Connectez le code de votre jeu au signal `inkminfeed`, comme expliqué dans la section suivante, et interprétez le dictionnaire pour afficher les dialogues, créer les boutons de choix et réagir aux instructions du scénario.

### Connecter le code de votre jeu au lecteur Inkmin
Dans le script qui contrôle l'interface de dialogue, obtenez une référence au nœud lecteur. Indiquez dans `dialoguefolder` le dossier contenant les fichiers JSON, avec une barre oblique finale. Connectez `inkminfeed` avant de démarrer l'histoire afin de recevoir les premiers événements. Appelez `initiatedialogs()` pour charger les langues, les variables et la liste des nœuds depuis `root.json`, définissez `currentlang`, puis appelez `loadandstartknot("root")`.

Par exemple, si le nœud lecteur s'appelle `inkminreader` et les fichiers JSON se trouvent dans `res://dialogues/` :

```gdscript
@onready var inkmin = $inkminreader

func _ready() -> void:
	inkmin.dialoguefolder = "res://dialogues/"
	inkmin.inkminfeed.connect(_on_inkminfeed)
	inkmin.initiatedialogs()
	inkmin.currentlang = inkmin.languages[0]
	inkmin.loadandstartknot("root")

func _on_inkminfeed(output: Dictionary) -> void:
	print(output)
```

### Traiter les événements du lecteur
Vérifiez quelle clé contient le dictionnaire `output` :

- `text` : affichez la ligne de dialogue ou de narration.
- `choice` : affichez un bouton portant le texte `output.choice`. Lorsqu'il est sélectionné, appelez `inkmin.choicemade(str(output.next), str(output.get("blocid", "")))` pour continuer.
- `choicemade` : effacez les anciens choix ou dialogues avant d'afficher la conséquence.
- `signal` : interprétez `output.signal` comme une instruction propre au jeu, par exemple pour jouer un son.
- `newknot` : mettez à jour l'interface lorsque l'histoire passe à un autre nœud.
- `varchange` : lisez la nouvelle valeur dans `inkmin.playervars` et mettez à jour l'état du jeu qui en dépend.
- `theend` : gérez la fin du dialogue.

Pour voir un exemple fonctionnel, ouvrez le dépôt comme projet Godot, lancez `samples/dialogbox_example.tscn` et consultez `samples/dialogbox_example.gd` avec les fichiers narratifs de `samples/jsons/`.

## Créateur de scénario

Le créateur de scénario est une aide visuelle simple pour créer des graphes de scénario. Il est indépendant du système Inkmin.
Le scénario est enregistré dans un fichier JSON distinct. Une prise en charge de ce JSON par le code du jeu pourrait être envisagée dans une version ultérieure.

### Ajouter et modifier des nœuds
Les types de nœuds prédéfinis sont `cutscene`, `scenario event`, `dialog` et `unlock tech`. Des types de nœuds personnalisés peuvent être créés (voir ci-dessous).
Cliquez sur un type de nœud dans la barre supérieure pour ajouter un nœud au centre de la vue actuelle. Renseignez son nom, sa description et son champ de conditions lorsqu’il est disponible. Faites glisser sa barre de titre pour le déplacer et utilisez son coin inférieur droit pour le redimensionner.

### Personnaliser les types de nœuds
Cliquez sur `create node` pour définir un nouveau type de nœud. Saisissez un nom unique et cochez éventuellement `Add condition` pour inclure un champ de conditions. Le nouveau type apparaît sous forme de bouton dans la barre supérieure ; cliquez dessus pour créer des nœuds de ce type.
Cliquez sur `C` dans la barre de titre d’un nœud pour renommer son type. Cela modifie tous les nœuds de ce type, et non le champ de nom d’un seul nœud.
Utilisez `erase node` pour retirer un type de la barre supérieure. Un type ne peut être supprimé que lorsqu’aucun nœud de ce type ne reste sur le canevas.

### Relier les nœuds
Faites glisser une connexion du port situé à droite d’un nœud vers le port situé à gauche d’un autre nœud pour la créer. Pour supprimer une connexion, détachez-la de son port d’entrée sur le nœud de droite.

### Organiser avec des groupes
Cliquez sur `create group` pour ajouter un cadre nommé derrière les nœuds. Modifiez son nom dans l’en-tête, faites glisser l’en-tête pour déplacer le cadre et utilisez sa poignée en bas à droite pour le redimensionner.
Les groupes sont des repères visuels : déplacer un groupe ne déplace pas les nœuds qu’il contient.

### Enregistrer et charger
Cliquez sur `save` pour choisir un fichier `.json` pour le graphe. Il contient les types de nœuds, leurs textes, positions et dimensions, les connexions et les groupes. Le bouton d’enregistrement devient rose lorsque des modifications doivent être enregistrées.
Cliquez sur `load` pour ouvrir un graphe enregistré ; le chargement remplace le graphe actuel, donc enregistrez d’abord les modifications à conserver.
