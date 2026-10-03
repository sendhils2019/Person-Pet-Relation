---
name: pet-person-jpa
description: Implement the Pet/Person JPA relationship, Person.getPets(), Pet.getOwnerName() and PersonService.addPet() in a Java 17+ / Spring Boot 3 project, then verify with H2-backed tests via run.sh.
---

# Skill: Pet ↔ Person relationship (Java, Spring Boot 3, JPA/Hibernate)

## Goal
Complete these five tasks in the existing project, keep all existing public
signatures unchanged, and finish with a green test run.

1. Register `PersonService` as a Spring bean.
2. Model the relationship between `Pet` and `Person` with class fields and JPA/Hibernate annotations.
3. Implement `Person.getPets()` – returns all pets of the person.
4. Implement `Pet.getOwnerName()` – returns the owner's **first name**.
5. Implement `PersonService.addPet(...)` – adds a pet with the given name to the person with the given id;
   if no such person exists, throw `PersonNotFoundException`.

## Ground rules (read before editing)
- **Inspect first.** Open `Person`, `Pet`, `PersonService`, any repository interfaces, any existing
  exception classes and existing tests. Reuse what exists; do not create duplicates.
- **Do not rename or change signatures** of existing classes/methods (tests may be hidden/graded).
  Match the existing id type (`Long` vs `long` vs `Integer`) and parameter order of `addPet`.
- Spring Boot 3 ⇒ use **`jakarta.persistence.*`**, never `javax.persistence.*`.
- Constructor injection only; no field `@Autowired`.
- Never include `pets` or `owner` in `toString()`, `equals()` or `hashCode()` (avoids infinite recursion
  and lazy-loading errors). Do not use Lombok `@Data` on these entities.
- If `pom.xml`/`build.gradle` lacks a test DB, add **H2** with `test` scope (and `spring-boot-starter-test`
  if missing). Do not touch the production datasource config.

## Task 1 – Register PersonService as a bean
Annotate the class with `@Service` (it must live under the `@SpringBootApplication` package so component
scanning finds it). Inject the repository through the constructor.

```java
@Service
public class PersonService {
    private final PersonRepository personRepository;

    public PersonService(PersonRepository personRepository) {
        this.personRepository = personRepository;
    }
}
```

If no repository exists, create one next to the entities:

```java
public interface PersonRepository extends JpaRepository<Person, Long> { }
```

## Task 2 – Model the relationship
One `Person` owns many `Pet`s. `Pet` is the owning side (holds the foreign key).

**Person**
```java
@Entity
public class Person {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String firstName;
    private String lastName;

    @OneToMany(mappedBy = "owner", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Pet> pets = new ArrayList<>();

    /** Keeps both sides of the association in sync. */
    public void addPet(Pet pet) {
        pets.add(pet);
        pet.setOwner(this);
    }
    // keep existing constructors/getters/setters
}
```

**Pet**
```java
@Entity
public class Pet {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "owner_id")
    private Person owner;

    public Person getOwner() { return owner; }
    public void setOwner(Person owner) { this.owner = owner; }
    // keep existing constructors/getters/setters
}
```

Notes:
- If the entities already declare ids/columns, keep those and add only the relationship fields.
- JPA needs a no-arg constructor (`public` or `protected`) on both entities.

## Task 3 – Person.getPets()
Return the person's pet collection (all pets). Never return `null`.

```java
public List<Pet> getPets() {
    return pets;
}
```

Keep the existing return type if it differs (e.g. `Set<Pet>`); then declare the field with that type.

## Task 4 – Pet.getOwnerName()
Return the owner's first name; return `null` when the pet has no owner (no NPE).

```java
public String getOwnerName() {
    return owner != null ? owner.getFirstName() : null;
}
```

If the method is a mapped bean getter and the project uses JSON/JPA property access, mark it
`@Transient` (`jakarta.persistence.Transient`) so it is not treated as a column.

## Task 5 – PersonService.addPet()
```java
@Transactional
public Pet addPet(Long personId, String petName) {
    Person person = personRepository.findById(personId)
            .orElseThrow(() -> new PersonNotFoundException(personId));

    Pet pet = new Pet();
    pet.setName(petName);
    person.addPet(pet);          // sets both sides

    personRepository.save(person); // cascade persists the pet
    return pet;
}
```
- Keep the existing return type (`void`, `Pet`, or `Person`) — adapt the `return` line accordingly.
- Use `org.springframework.transaction.annotation.Transactional`.

If `PersonNotFoundException` does not exist, create it:

```java
@ResponseStatus(HttpStatus.NOT_FOUND)
public class PersonNotFoundException extends RuntimeException {
    public PersonNotFoundException(Long id) {
        super("Person not found with id: " + id);
    }
}
```

## Tests (H2, in-memory)
Create `src/test/java/<base package>/PersonServiceTest.java`:

```java
@SpringBootTest
@Transactional
class PersonServiceTest {

    @Autowired PersonService personService;
    @Autowired PersonRepository personRepository;

    @Test
    void personServiceIsRegisteredAsBean() {
        assertNotNull(personService);
    }

    @Test
    void addPetAddsPetToExistingPerson() {
        Person p = new Person();
        p.setFirstName("John");
        p.setLastName("Doe");
        p = personRepository.save(p);

        personService.addPet(p.getId(), "Rex");

        Person reloaded = personRepository.findById(p.getId()).orElseThrow();
        assertEquals(1, reloaded.getPets().size());
        Pet pet = reloaded.getPets().get(0);
        assertEquals("Rex", pet.getName());
        assertEquals("John", pet.getOwnerName());
    }

    @Test
    void addPetThrowsWhenPersonMissing() {
        assertThrows(PersonNotFoundException.class,
                () -> personService.addPet(9999L, "Ghost"));
    }

    @Test
    void getOwnerNameIsNullWithoutOwner() {
        assertNull(new Pet().getOwnerName());
    }
}
```

`src/test/resources/application.properties` (create only if tests have no datasource):
```properties
spring.datasource.url=jdbc:h2:mem:testdb;DB_CLOSE_DELAY=-1
spring.datasource.driver-class-name=org.h2.Driver
spring.jpa.hibernate.ddl-auto=create-drop
spring.jpa.show-sql=false
```

Maven dependency if missing:
```xml
<dependency>
  <groupId>com.h2database</groupId>
  <artifactId>h2</artifactId>
  <scope>test</scope>
</dependency>
```
Gradle: `testRuntimeOnly 'com.h2database:h2'`

## Run / verify
Run `./run.sh` from the project root (make it executable with `chmod +x run.sh`).
It detects Maven or Gradle, cleans, compiles and runs all tests.

**Definition of done**
- `./run.sh` exits 0 and all tests pass, including any pre-existing tests.
- No `javax.persistence` imports; no changed public signatures.
- `PersonService` is injectable; `addPet` persists the pet and throws `PersonNotFoundException` for unknown ids.

If a test fails, read the failure, fix the cause in main code (not by weakening the test), and re-run.
