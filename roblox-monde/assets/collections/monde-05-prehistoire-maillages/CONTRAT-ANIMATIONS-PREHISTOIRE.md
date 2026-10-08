# Consigne d'anatomie et d'animation — Préhistoire

À transmettre à l'assistant qui fabrique ou intègre les prochains modèles :

**Vélociraptor, Dilophosaure, Spinosaure et T-rex sont des bipèdes.** Leurs membres antérieurs sont des bras, pas des pattes porteuses. Il ne faut pas réutiliser la démarche à quatre pattes des mammifères précédents.

- Le poids et les appuis passent uniquement par les deux pattes arrière.
- Le cycle Walk alterne ces deux pattes, avec genoux et chevilles articulés ; compenser l'orientation des pieds pendant l'appui.
- Les petits bras restent près du torse, avec un léger mouvement de balance ; ils ne touchent pas le sol. Les bras du spinosaure peuvent être plus robustes, mais ne deviennent pas des pattes avant dans le style demandé.
- La longue queue accompagne l'équilibre et contrebalance les rotations et les attaques.
- Idle garde une posture bipède ; Attack et Bite utilisent les griffes, la tête et la mâchoire selon l'animal, sans animation de marche quadrupède.
- T-rex : bras très courts, grandes attaques de mâchoire et mouvements de tête lourds. Dilophosaure : collerette animable. Spinosaure : conserver la grande voile dorsale.

Le Tricératops reste quadrupède. Le Ptéranodon possède des ailes : prévoir son propre cycle de vol, sans lui donner quatre pattes de mammifère.

Pour tous : racine RigRoot, articulations Motor6D, dossier Animations avec Idle, Walk, Attack et Bite en KeyframeSequence. Maillages rigides séparés, moins de 20 pièces et cible de 4 000 à 6 000 triangles. Éviter toute oreille, œil, queue ou décoration détachée.

Les six modèles sont fournis dans ce lot. Le clip Walk du Ptéranodon est son cycle de vol, conservé sous ce nom pour respecter le lecteur. Les trajectoires aériennes et collisions seront à intégrer séparément dans le jeu.

Tous les clips s'utilisent avec gain 1 ; ne pas appliquer le gain global 2.6 conçu pour les anciens animaux. Le jeu n'est pas modifié. Le FBX contient les maillages rigides ; les Motor6D et KeyframeSequence sont dans le gabarit RBXMX à assembler.
